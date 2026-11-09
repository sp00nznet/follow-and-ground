# Headless check of the session rules: godot --headless --path . -s tools/selftest.gd
extends SceneTree

var fails := 0
func ok(c: bool, name: String) -> void:
	print(("PASS " if c else "FAIL ") + name)
	if not c: fails += 1

func _init() -> void:
	var t := Guide.TUNING
	var s := Core.initial()
	for e in [{"type": "ack"}, {"type": "done"}]: s = Core.step(s, e, t)
	ok(s.phase == "target", "safety -> calm place -> target")
	s = Core.step(s, {"type": "sud", "value": 4}, t); ok(s.phase == "setIntro", "mild rating starts a set")
	s = Core.step(s, {"type": "done"}, t); ok(s.phase == "set" and s.set == 1, "set 1")
	s = Core.step(s, {"type": "done"}, t); ok(s.phase == "setOutro", "set ends")
	s = Core.step(s, {"type": "sud", "value": 9}, t); ok(s.phase == "highSud", "high rating offers grounding")
	for i in 2:
		s = Core.step(s, {"type": "continue"}, t)
		s = Core.step(Core.step(s, {"type": "done"}, t), {"type": "done"}, t)
		s = Core.step(s, {"type": "sud", "value": 9}, t)
	ok(s.phase == "closing", "third high rating in a row grounds without asking")
	s = Core.step(s, {"type": "done"}, t); ok(s.phase == "end", "closing -> end")
	for p in ["safePlace", "target", "setIntro", "set", "setOutro", "highSud"]:
		var x := Core.initial(); x.phase = p
		ok(Core.step(x, {"type": "stop"}, t).phase == "closing", "stop from %s grounds" % p)
	var y := Core.initial(); y.phase = "setOutro"; y.set = 3
	ok(Core.step(y, {"type": "sud", "value": 1}, t).phase == "closing", "rating 1 closes")
	ok(Core.clamp_sud(14) == 10 and Core.clamp_sud(-2) == 0, "rating clamps to 0-10")
	for path in Core.PATHS.size():
		var mx := 0.0
		for i in 400: mx = maxf(mx, absf(Core.prop_pos(path, i * 0.01, 1.0, 0.8).x))
		ok(mx <= 0.8 + 1e-4 and mx > 0.7, "path %s stays within width" % Core.PATHS[path])
	for k in [1, 2, 3]:
		var st := PackedFloat32Array([0, 0, 0, 0]); var peak := 0.0
		for i in 44100: peak = maxf(peak, absf(Core.noise(k, randf() * 2 - 1, st)))
		ok(peak > 0.05 and peak <= 1.6, "%s noise in range (%.2f)" % [Core.NOISES[k], peak])
	print("%d failed" % fails)
	quit(1 if fails else 0)
