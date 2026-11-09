# Regenerates docs/screenshots by driving one session: godot --path . -s tools/shots.gd
extends SceneTree

var m
func snap(name: String) -> void:
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
	print("saved ", name)

func phase(p: String) -> void:
	while m.S.phase != p: await process_frame

func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ratings.json"))
	m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	await process_frame
	m.opt.voice = false; m.ui.ack.button_pressed = true
	await snap("safety")
	m.T.merge({"line_pause": 1.0, "question_pause": 1.0, "set_seconds": 3.0}, true)
	m._begin(); await phase("safePlace"); await create_timer(0.5).timeout; await snap("calm-place")
	await phase("target"); await create_timer(0.5).timeout; await snap("target")
	while not m.ui.sud.visible: await process_frame
	await snap("sud"); m._rate(5)
	await phase("set"); await create_timer(0.3).timeout; await snap("set")
	m.opt.prop = 1; m.opt.path = 1; await create_timer(0.6).timeout; await snap("buddy")
	m.opt.prop = 2; m.opt.path = 3; await create_timer(0.5).timeout; await snap("ring")
	while not m.ui.sud.visible: await process_frame
	m._rate(9); while not m.ui.choice.visible: await process_frame
	await snap("high-rating"); m.stop()
	await phase("closing"); await create_timer(0.5).timeout; await snap("grounding")
	while not m.ui.again.visible: await process_frame
	await snap("end"); m._restart(); for i in 3: await process_frame
	m.ui.safety.scroll_vertical = 10000; await snap("history")
	quit()
