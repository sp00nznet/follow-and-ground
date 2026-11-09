extends Node3D
# The whole app: safety screen, the 3D room and object, the session flow, voice and noise.
# Session rules live in core.gd and every spoken word in guide.gd.

const SAVE := "user://ratings.json"
const EYE := Vector3(0, 1.6, 0)
const AHEAD := 2.0

var T := Guide.TUNING.duplicate()
var opt := {"prop": 0, "path": 0, "noise": 0, "volume": 0.3, "voice": true}
var S := Core.initial()
var run := 0          # bumped on every phase change; stale awaits check it and bail
var fast := false     # tools/ test hook: squeezes every wait
var set_t := -1.0     # seconds into the current set, -1 when the object is at rest
var props: Array[Node3D] = []
var line3d: Label3D
var ui := {}
var noise_pb: AudioStreamGeneratorPlayback
var noise_st := PackedFloat32Array([0, 0, 0, 0])
var pan := 0.0
var voice_id := ""

func _ready() -> void:
	fast = "--fast" in OS.get_cmdline_user_args()
	if fast: T.merge({"line_pause": 0.05, "question_pause": 0.05, "set_seconds": 2.0}, true)
	_build_room()
	_build_ui()
	_start_noise()
	var voices := DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
	if voices.size(): voice_id = voices[0]
	_show_history()

# ---------- 3D ----------
func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1e2629")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa9a8")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); sun.light_energy = 0.8; add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor.mesh = pm
	floor.material_override = _mat(Color("2a3437")); add_child(floor)

	# XR if a runtime is there (headset or simulator); otherwise a plain desktop camera. Same scene either way.
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		get_viewport().use_xr = true
		var origin := XROrigin3D.new(); add_child(origin); origin.add_child(XRCamera3D.new())
	else:
		var cam := Camera3D.new(); cam.position = EYE; add_child(cam)

	# Props: a soft orb, a little buddy (the "puppet"), a ring. One is visible at a time.
	var orb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18; orb.mesh = sm
	orb.material_override = _mat(Color("a3d4c2"), true)
	var buddy := Node3D.new()
	var body := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.07; cm.height = 0.22; body.mesh = cm
	body.material_override = _mat(Color("e3d3a8")); buddy.add_child(body)
	var head := MeshInstance3D.new(); var hm := SphereMesh.new(); hm.radius = 0.075; hm.height = 0.15; head.mesh = hm
	head.position.y = 0.17; head.material_override = _mat(Color("e3d3a8")); buddy.add_child(head)
	for x in [-0.028, 0.028]:
		var eye := MeshInstance3D.new(); var em := SphereMesh.new(); em.radius = 0.014; em.height = 0.028; eye.mesh = em
		eye.position = Vector3(x, 0.185, 0.065); eye.material_override = _mat(Color("1e2629")); buddy.add_child(eye)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.07; tm.outer_radius = 0.11; ring.mesh = tm
	ring.rotation_degrees.x = 90; ring.material_override = _mat(Color("9cc3e0"), true)
	props = [orb, buddy, ring]
	for p in props: add_child(p)
	_place_props(Vector3.ZERO)

	line3d = Label3D.new(); line3d.position = EYE + Vector3(0, 0.55, -AHEAD - 0.5); line3d.pixel_size = 0.0022
	line3d.font_size = 64; line3d.width = 1100; line3d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line3d.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM; line3d.position.y -= 0.12; line3d.modulate = Color("e8eeec"); line3d.outline_size = 0; add_child(line3d)

func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.7
	if glow: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 0.6
	return m

func _place_props(off: Vector3) -> void:
	for i in props.size():
		props[i].visible = i == opt.prop and not (ui.has("safety") and ui.safety.visible)
		props[i].position = EYE + Vector3(0, 0, -AHEAD) + off

func _process(dt: float) -> void:
	var off := Vector3.ZERO
	if set_t >= 0.0:
		set_t += dt
		off = Core.prop_pos(opt.path, set_t, T.hz, T.width)
		props[opt.prop].rotation.y = sin(TAU * T.hz * set_t) * 0.4
	_place_props(off)
	pan = off.x / T.width if set_t >= 0.0 else 0.0
	_fill_noise()

# ---------- noise (bilateral: pans with the object during a set) ----------
func _start_noise() -> void:
	var gen := AudioStreamGenerator.new(); gen.mix_rate = 44100; gen.buffer_length = 0.2
	var p := AudioStreamPlayer.new(); p.stream = gen; add_child(p); p.play()
	noise_pb = p.get_stream_playback()

func _fill_noise() -> void:
	var n := noise_pb.get_frames_available()
	var l: float = sqrt((1.0 - pan) * 0.5) * opt.volume
	var r: float = sqrt((1.0 + pan) * 0.5) * opt.volume
	for i in n:
		var v := Core.noise(opt.noise, randf() * 2.0 - 1.0, noise_st)
		noise_pb.push_frame(Vector2(v * l, v * r))

# ---------- 2D UI ----------
func _build_ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(root)
	var theme := Theme.new(); theme.default_font_size = 15; root.theme = theme

	# Safety screen
	# Scrolls when it outgrows the window, and always stops above the crisis-line footer.
	var scroll := ScrollContainer.new(); scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 12; scroll.offset_bottom = -64; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll); ui.safety = scroll
	var center := CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(560, 0); center.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); panel.add_child(_pad(v, 22))
	var h := Label.new(); h.text = "Before you start"; h.add_theme_font_size_override("font_size", 26); v.add_child(h)
	var d := Label.new(); d.text = Guide.DISCLAIMER; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(d)
	v.add_child(_choice("Object", ["Orb", "Buddy", "Ring"], "prop"))
	v.add_child(_choice("Movement", Core.PATHS, "path"))
	v.add_child(_choice("Background noise", Core.NOISES, "noise"))
	v.add_child(_slider("Noise volume", 0.0, 1.0, 0.05, opt.volume, func(x): opt.volume = x))
	v.add_child(_slider("Speed (sweeps/s)", 0.3, 1.5, 0.1, T.hz, func(x): T.hz = x))
	v.add_child(_slider("Set length (s)", 15, 40, 5, T.set_seconds, func(x): T.set_seconds = x))
	var voice := CheckBox.new(); voice.text = "Speak the guide aloud (your computer's own voice, offline)"; voice.button_pressed = opt.voice
	voice.toggled.connect(func(b): opt.voice = b); v.add_child(voice)
	var ack := CheckBox.new(); ack.text = "I understand this is not therapy, and I can stop at any time."; v.add_child(ack)
	var begin := Button.new(); begin.text = "Begin"; begin.disabled = true; v.add_child(begin)
	ack.toggled.connect(func(b): begin.disabled = not b)
	begin.pressed.connect(_begin); ui.ack = ack; ui.begin = begin
	var hist := VBoxContainer.new(); v.add_child(hist); ui.hist = hist

	# Session controls, centred under the object
	var mid := VBoxContainer.new(); mid.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); mid.position.y -= 190
	mid.grow_horizontal = Control.GROW_DIRECTION_BOTH; mid.alignment = BoxContainer.ALIGNMENT_CENTER; root.add_child(mid)
	var sud := HBoxContainer.new(); sud.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 11:
		var b := Button.new(); b.text = str(i); b.custom_minimum_size = Vector2(46, 46)
		b.pressed.connect(_rate.bind(i)); sud.add_child(b)
	var sudbox := VBoxContainer.new(); var hint := Label.new(); hint.text = "0 is calm, 10 is the most upsetting. (Keys 0-9 work too.)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sudbox.add_child(hint); sudbox.add_child(sud); mid.add_child(sudbox); ui.sud = sudbox
	var choice := HBoxContainer.new(); choice.alignment = BoxContainer.ALIGNMENT_CENTER
	var g := Button.new(); g.text = "Ground me"; g.pressed.connect(stop); choice.add_child(g)
	var k := Button.new(); k.text = "Keep going"; k.pressed.connect(func(): go({"type": "continue"})); choice.add_child(k)
	mid.add_child(choice); ui.choice = choice
	var again := Button.new(); again.text = "Back to start"; again.pressed.connect(_restart); mid.add_child(again); ui.again = again

	var stopb := Button.new(); stopb.text = "Stop / Ground me (Esc)"; stopb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stopb.position = Vector2(-240, -110); stopb.custom_minimum_size = Vector2(220, 52); root.add_child(stopb); ui.stop = stopb
	stopb.pressed.connect(stop)

	# Crisis lines, always visible
	var foot := HBoxContainer.new(); foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); foot.position.y -= 44
	foot.alignment = BoxContainer.ALIGNMENT_CENTER; foot.add_theme_constant_override("separation", 30); root.add_child(foot)
	for c in Guide.CRISIS:
		var l := LinkButton.new(); l.text = c[0]; l.pressed.connect(OS.shell_open.bind(c[1])); foot.add_child(l)
	_hide_all(); ui.stop.visible = false

func _pad(c: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, px)
	m.add_child(c); return m

func _choice(label: String, items: Array, key: String) -> HBoxContainer:
	var h := HBoxContainer.new(); var l := Label.new(); l.text = label; l.custom_minimum_size.x = 170; h.add_child(l)
	var o := OptionButton.new(); for it in items: o.add_item(it)
	o.selected = opt[key]; o.item_selected.connect(func(i): opt[key] = i); h.add_child(o); return h

func _slider(label: String, lo: float, hi: float, st: float, val: float, set_fn: Callable) -> HBoxContainer:
	var h := HBoxContainer.new(); var l := Label.new(); l.text = label; l.custom_minimum_size.x = 170; h.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = st; s.value = val; s.custom_minimum_size.x = 220
	var out := Label.new(); out.text = str(val)
	s.value_changed.connect(func(x): set_fn.call(x); out.text = str(x)); h.add_child(s); h.add_child(out); return h

func _hide_all() -> void:
	ui.sud.visible = false; ui.choice.visible = false; ui.again.visible = false
	set_t = -1.0

# ---------- ratings, kept in this app's user folder only ----------
func _load() -> Array:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if not f: return []
	var j = JSON.parse_string(f.get_as_text())
	return j if j is Array else []

func _log(sud: int) -> void:
	var log := _load(); log.append({"t": Time.get_datetime_string_from_system(), "set": S.set, "sud": sud})
	FileAccess.open(SAVE, FileAccess.WRITE).store_string(JSON.stringify(log))

func _show_history() -> void:
	for c in ui.hist.get_children(): c.queue_free()
	var log := _load()
	if log.is_empty(): return
	var t := Label.new(); t.text = "My ratings"; ui.hist.add_child(t)
	for e in log.slice(-8):
		var l := Label.new(); l.text = "%s   set %d, rating %d" % [e.t.replace("T", " "), e.set, e.sud]; ui.hist.add_child(l)
	var del := Button.new(); del.text = "Delete my data"; ui.hist.add_child(del)
	del.pressed.connect(func(): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE)); _show_history())

# ---------- session ----------
func _begin() -> void:
	ui.safety.visible = false; ui.stop.visible = true
	go({"type": "ack"})

func _restart() -> void:
	S = Core.initial(); run += 1; _hide_all(); line3d.text = ""
	ui.ack.button_pressed = false; ui.safety.visible = true; ui.stop.visible = false; _show_history()

func stop() -> void:
	if S.phase == "safety": return
	DisplayServer.tts_stop()
	go({"type": "stop"})

func _rate(v: int) -> void:
	if not ui.sud.visible: return
	_log(v); go({"type": "sud", "value": v})

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"): stop()
	elif e is InputEventKey and e.pressed and e.keycode >= KEY_0 and e.keycode <= KEY_9: _rate(e.keycode - KEY_0)

func go(ev: Dictionary) -> void:
	S = Core.step(S, ev, T)
	run += 1; var my := run
	_hide_all()
	match S.phase:
		"safePlace", "setIntro", "closing":
			if await _say_all(S.phase, my): go({"type": "done"})
		"target", "setOutro":
			if await _say_all(S.phase, my): ui.sud.visible = true
		"set":
			line3d.text = "Set %d" % S.set; set_t = 0.0
			if await _wait(T.set_seconds, my): go({"type": "done"})
		"highSud":
			if await _say_all(S.phase, my): ui.choice.visible = true
		"end":
			ui.stop.visible = false
			if await _say_all(S.phase, my): ui.again.visible = true

func _wait(sec: float, my: int) -> bool:
	await get_tree().create_timer(sec).timeout
	return my == run

func _say_all(key: String, my: int) -> bool:
	for line in Guide.LINES[key]:
		line3d.text = line
		if opt.voice and voice_id != "" and not fast:
			DisplayServer.tts_speak(line, voice_id)
			while DisplayServer.tts_is_speaking():
				if not await _wait(0.1, my): return false
		var q: bool = line.ends_with("?")
		if not await _wait(T.question_pause if q else T.line_pause, my): return false
	return true
