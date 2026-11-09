# Pure session logic, no nodes, so tools/selftest.gd can check it headless.
class_name Core

const PATHS := ["Side to side", "Figure eight", "Circle", "Near and far"]
const NOISES := ["Off", "White", "Pink", "Brown"]

static func initial() -> Dictionary:
	return {"phase": "safety", "set": 0, "continues": 0, "last_sud": -1}

# ev: {type: ack|done|sud|continue|stop, value?}
static func step(s: Dictionary, ev: Dictionary, t: Dictionary) -> Dictionary:
	var n := s.duplicate()
	var p: String = s.phase
	match ev.type:
		"stop":
			n.phase = "end" if p in ["closing", "end"] else "closing"
		"ack":
			if p == "safety": n.phase = "safePlace"
		"done":
			n.phase = {"safePlace": "target", "setIntro": "set", "set": "setOutro", "closing": "end"}.get(p, p)
			if p == "setIntro": n.set += 1
		"sud":
			if p in ["target", "setOutro"]:
				var v := clamp_sud(ev.value)
				n.last_sud = v
				if v >= t.high_sud:
					# Two "keep going"s in a row at a high rating is the limit; then it grounds without asking.
					n.phase = "closing" if s.continues >= 2 else "highSud"
				else:
					n.continues = 0
					n.phase = "closing" if p == "setOutro" and (v <= 1 or s.set >= t.sets_max) else "setIntro"
		"continue":
			if p == "highSud":
				if s.set >= t.sets_max: n.phase = "closing"
				else:
					n.continues += 1
					n.phase = "setIntro"
	return n

static func clamp_sud(v) -> int:
	return clampi(roundi(float(v)), 0, 10)

# Where the object sits, relative to straight ahead at `dist` metres. Sine easing, never a hard bounce.
# x in [-width, width] (metres at dist 2), so pan = x / width.
static func prop_pos(path: int, t: float, hz: float, width: float) -> Vector3:
	var a := TAU * hz * t
	match path:
		1: return Vector3(sin(a) * width, sin(2.0 * a) * width * 0.3, 0.0)
		2: return Vector3(sin(a) * width, cos(a) * width * 0.5, 0.0)
		3: return Vector3(sin(a) * width, 0.0, cos(a) * 1.2)
		_: return Vector3(sin(a) * width, 0.0, 0.0)

# One noise sample. state is [pink b0..b2, brown last]; white in [-1, 1].
static func noise(kind: int, white: float, st: PackedFloat32Array) -> float:
	match kind:
		1: return white * 0.5
		2:  # Paul Kellet's economy pink filter
			st[0] = 0.99765 * st[0] + white * 0.0990460
			st[1] = 0.96300 * st[1] + white * 0.2965164
			st[2] = 0.57000 * st[2] + white * 1.0526913
			return (st[0] + st[1] + st[2] + white * 0.1848) * 0.12
		3:
			st[3] = clampf(st[3] + white * 0.02, -1.0, 1.0) * 0.998
			return st[3] * 1.5
	return 0.0
