extends Control
class_name AtmosphericEffects
## 環境パーティクルおよび空気感エフェクト（火の粉・雨・朝霧・月光・陽光・塵）の描画クラス

const EFFECT_NONE := "none"

var current_effect: String = EFFECT_NONE
var _fade_alpha: float = 0.0
var _target_alpha: float = 0.0
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()

var _particles: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	resized.connect(_on_resized)


func _on_resized() -> void:
	if current_effect != EFFECT_NONE and not current_effect.is_empty():
		_rebuild_particles()


func set_effect(effect_name: String, immediate: bool = false) -> void:
	var normalized := effect_name.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = EFFECT_NONE
	if normalized == current_effect:
		return

	current_effect = normalized
	_particles.clear()
	_beams.clear()
	_splashes.clear()

	if current_effect == EFFECT_NONE:
		_target_alpha = 0.0
		if immediate:
			_fade_alpha = 0.0
		queue_redraw()
		return

	_target_alpha = 1.0
	_fade_alpha = 1.0 if immediate else 0.0
	_rebuild_particles()
	queue_redraw()


func _rebuild_particles() -> void:
	var w: float = maxf(size.x, 1920.0)
	var h: float = maxf(size.y, 1080.0)
	_particles.clear()
	_beams.clear()
	_splashes.clear()

	match current_effect:
		"embers":
			for i in 88:
				_particles.append(_make_ember(w, h, true))
		"rain":
			for i in 145:
				_particles.append(_make_raindrop(w, h, true))
		"mist":
			for i in 4:
				_beams.append({
					"x": w * (0.24 + i * 0.16) + _rng.randf_range(-30.0, 30.0),
					"width": _rng.randf_range(95.0, 175.0),
					"skew": _rng.randf_range(160.0, 260.0),
					"phase": _rng.randf_range(0.0, TAU),
					"speed": _rng.randf_range(0.30, 0.55),
					"alpha": _rng.randf_range(0.022, 0.048),
				})
			for i in 26:
				_particles.append(_make_mist_cloud(w, h, true))
		"moonlight":
			for i in 4:
				_beams.append({
					"x": w * (0.48 + i * 0.14) + _rng.randf_range(-45.0, 45.0),
					"width": _rng.randf_range(112.5, 225.0),
					"skew": _rng.randf_range(-360.0, -255.0),
					"phase": _rng.randf_range(0.0, TAU),
					"speed": _rng.randf_range(0.35, 0.65),
					"alpha": _rng.randf_range(0.04, 0.082),
				})
			for i in 54:
				_particles.append(_make_moon_mote(w, h))
		"sunbeams":
			for i in 5:
				_beams.append({
					"x": w * (0.18 + i * 0.17) + _rng.randf_range(-37.5, 37.5),
					"width": _rng.randf_range(135.0, 285.0),
					"skew": _rng.randf_range(240.0, 375.0),
					"phase": _rng.randf_range(0.0, TAU),
					"speed": _rng.randf_range(0.45, 0.85),
					"alpha": _rng.randf_range(0.05, 0.10),
				})
			for i in 48:
				_particles.append(_make_sun_sparkle(w, h))
		"dust":
			for i in 62:
				_particles.append(_make_dust_mote(w, h))


func _make_ember(w: float, h: float, scatter_y: bool) -> Dictionary:
	var layer := _rng.randf()
	return {
		"x": _rng.randf_range(-60.0, w + 60.0),
		"y": _rng.randf_range(0.0, h) if scatter_y else h + _rng.randf_range(12.0, 120.0),
		"vx": _rng.randf_range(-36.0, 27.0),
		"vy": _rng.randf_range(-217.5, -67.5) * (0.65 + layer * 0.65),
		"radius": lerpf(2.1, 6.3, layer),
		"life": _rng.randf_range(0.0, TAU),
		"wobble_freq": _rng.randf_range(1.6, 3.8),
		"wobble_amp": _rng.randf_range(18.0, 57.0),
		"alpha": _rng.randf_range(0.45, 0.95),
		"hue_pick": _rng.randf(),
	}


func _make_raindrop(w: float, h: float, scatter_y: bool) -> Dictionary:
	var depth := _rng.randf()
	return {
		"x": _rng.randf_range(-180.0, w + 270.0),
		"y": _rng.randf_range(-120.0, h) if scatter_y else _rng.randf_range(-240.0, -30.0),
		"speed": lerpf(870.0, 1620.0, depth),
		"length": lerpf(24.0, 54.0, depth),
		"angle_dx": -0.18,
		"width": lerpf(1.35, 2.7, depth),
		"alpha": lerpf(0.14, 0.42, depth),
	}


func _make_mist_cloud(w: float, h: float, scatter_x: bool) -> Dictionary:
	var radius_x := _rng.randf_range(315.0, 630.0)
	return {
		"x": _rng.randf_range(-radius_x, w + radius_x) if scatter_x else -radius_x,
		"y": _rng.randf_range(h * 0.44, h * 0.96),
		"vx": _rng.randf_range(21.0, 57.0),
		"rx": radius_x,
		"ry": _rng.randf_range(72.0, 165.0),
		"phase": _rng.randf_range(0.0, TAU),
		"alpha": _rng.randf_range(0.035, 0.085),
	}


func _make_moon_mote(w: float, h: float) -> Dictionary:
	return {
		"x": _rng.randf_range(0.0, w),
		"y": _rng.randf_range(0.0, h * 0.85),
		"vx": _rng.randf_range(-12.0, 9.0),
		"vy": _rng.randf_range(-15.0, 12.0),
		"radius": _rng.randf_range(1.8, 4.5),
		"phase": _rng.randf_range(0.0, TAU),
		"twinkle_speed": _rng.randf_range(1.2, 2.8),
		"alpha": _rng.randf_range(0.25, 0.68),
	}


func _make_sun_sparkle(w: float, h: float) -> Dictionary:
	return {
		"x": _rng.randf_range(0.0, w),
		"y": _rng.randf_range(0.0, h * 0.88),
		"vx": _rng.randf_range(12.0, 39.0),
		"vy": _rng.randf_range(-21.0, 9.0),
		"radius": _rng.randf_range(2.25, 5.4),
		"phase": _rng.randf_range(0.0, TAU),
		"twinkle_speed": _rng.randf_range(1.8, 3.8),
		"alpha": _rng.randf_range(0.28, 0.75),
	}


func _make_dust_mote(w: float, h: float) -> Dictionary:
	return {
		"x": _rng.randf_range(0.0, w),
		"y": _rng.randf_range(h * 0.08, h * 0.88),
		"vx": _rng.randf_range(-9.0, 15.0),
		"vy": _rng.randf_range(-13.5, 7.5),
		"radius": _rng.randf_range(1.5, 3.6),
		"phase": _rng.randf_range(0.0, TAU),
		"alpha": _rng.randf_range(0.15, 0.45),
	}


func _process(delta: float) -> void:
	_time += delta
	if not is_equal_approx(_fade_alpha, _target_alpha):
		_fade_alpha = move_toward(_fade_alpha, _target_alpha, delta * 1.4)

	if _fade_alpha <= 0.001 and current_effect == EFFECT_NONE:
		return

	var w: float = maxf(size.x, 1920.0)
	var h: float = maxf(size.y, 1080.0)

	match current_effect:
		"embers":
			for i in _particles.size():
				var p: Dictionary = _particles[i]
				p["life"] += delta * p["wobble_freq"]
				p["x"] += (p["vx"] + sin(p["life"]) * p["wobble_amp"]) * delta
				p["y"] += p["vy"] * delta
				if p["y"] < -36.0 or p["x"] < -120.0 or p["x"] > w + 120.0:
					_particles[i] = _make_ember(w, h, false)
		"rain":
			for i in _particles.size():
				var p: Dictionary = _particles[i]
				var dy: float = p["speed"] * delta
				p["x"] += dy * p["angle_dx"]
				p["y"] += dy
				if p["y"] > h - 15.0:
					if _rng.randf() < 0.25 and _splashes.size() < 28:
						_splashes.append({
							"x": p["x"],
							"y": h - _rng.randf_range(12.0, 135.0),
							"age": 0.0,
							"max_age": _rng.randf_range(0.16, 0.26),
						})
					_particles[i] = _make_raindrop(w, h, false)
			for i in range(_splashes.size() - 1, -1, -1):
				_splashes[i]["age"] += delta
				if _splashes[i]["age"] >= _splashes[i]["max_age"]:
					_splashes.remove_at(i)
		"mist":
			for i in _particles.size():
				var p: Dictionary = _particles[i]
				p["x"] += p["vx"] * delta
				p["phase"] += delta * 0.45
				if p["x"] - p["rx"] > w + 60.0:
					_particles[i] = _make_mist_cloud(w, h, false)
		"moonlight", "sunbeams":
			for p in _particles:
				p["phase"] += delta * p["twinkle_speed"]
				p["x"] = wrapf(p["x"] + p["vx"] * delta, -15.0, w + 15.0)
				p["y"] = wrapf(p["y"] + p["vy"] * delta, -15.0, h * 0.9)
		"dust":
			for p in _particles:
				p["phase"] += delta * 1.1
				p["x"] = wrapf(p["x"] + (p["vx"] + sin(p["phase"]) * 6.0) * delta, -15.0, w + 15.0)
				p["y"] = wrapf(p["y"] + (p["vy"] + cos(p["phase"] * 0.8) * 4.5) * delta, 0.0, h * 0.92)

	queue_redraw()


func _draw() -> void:
	if _fade_alpha <= 0.001:
		return

	var w: float = maxf(size.x, 1920.0)
	var h: float = maxf(size.y, 1080.0)

	match current_effect:
		"embers":
			_draw_embers(w, h)
		"rain":
			_draw_rain(w, h)
		"mist":
			_draw_mist(w, h)
		"moonlight":
			_draw_moonlight(h)
		"sunbeams":
			_draw_sunbeams(h)
		"dust":
			_draw_dust(w, h)


func _draw_embers(w: float, h: float) -> void:
	var glow_pulse := 0.82 + 0.12 * sin(_time * 2.4) + 0.06 * sin(_time * 6.3)
	var glow_col := Color(0.68, 0.12, 0.06, 0.22 * _fade_alpha * glow_pulse)
	var mid_col := Color(0.75, 0.22, 0.08, 0.08 * _fade_alpha * glow_pulse)
	var clear_col := Color(0.62, 0.11, 0.08, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, h * 0.48), Vector2(w, h * 0.48), Vector2(w, h * 0.78), Vector2(0, h * 0.78)]),
		PackedColorArray([clear_col, clear_col, mid_col, mid_col])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, h * 0.74), Vector2(w, h * 0.74), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid_col, mid_col, glow_col, glow_col])
	)

	for p in _particles:
		var flicker: float = 0.65 + 0.35 * sin(float(p["life"]) * 2.3)
		var a: float = float(p["alpha"]) * flicker * _fade_alpha
		var r: float = float(p["radius"])
		var pos := Vector2(float(p["x"]), float(p["y"]))
		var vel_tail := Vector2(float(p["vx"]), float(p["vy"])) * 0.032

		var core_col: Color
		var halo_col: Color
		if float(p["hue_pick"]) < 0.35:
			core_col = Color(1.0, 0.88, 0.52, a)
			halo_col = Color(0.95, 0.45, 0.12, a * 0.34)
		elif float(p["hue_pick"]) < 0.75:
			core_col = Color(1.0, 0.52, 0.16, a)
			halo_col = Color(0.75, 0.14, 0.08, a * 0.30)
		else:
			core_col = Color(0.95, 0.24, 0.14, a)
			halo_col = Color(0.62, 0.10, 0.10, a * 0.26)

		draw_circle(pos, r * 2.6, halo_col)
		if r >= 3.2:
			draw_line(pos, pos - vel_tail, Color(core_col.r, core_col.g, core_col.b, a * 0.45), r * 0.85, true)
		draw_circle(pos, r, core_col)


func _draw_rain(w: float, h: float) -> void:
	var wet_top := Color(0.28, 0.36, 0.46, 0.0)
	var wet_bot := Color(0.22, 0.30, 0.40, 0.14 * _fade_alpha)
	draw_polygon(
		PackedVector2Array([Vector2(0, h * 0.55), Vector2(w, h * 0.55), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([wet_top, wet_top, wet_bot, wet_bot])
	)

	for p in _particles:
		var pos := Vector2(float(p["x"]), float(p["y"]))
		var dir := Vector2(float(p["angle_dx"]), 1.0).normalized()
		var tail: Vector2 = pos - dir * float(p["length"])
		var col := Color(0.76, 0.84, 0.94, float(p["alpha"]) * _fade_alpha)
		draw_line(tail, pos, col, float(p["width"]), true)

	for s in _splashes:
		var t: float = float(s["age"]) / float(s["max_age"])
		var a: float = (1.0 - t) * 0.36 * _fade_alpha
		var r: float = lerpf(3.0, 20.0, t)
		var col := Color(0.84, 0.90, 0.98, a)
		draw_arc(Vector2(float(s["x"]), float(s["y"])), r, PI * 1.05, PI * 1.95, 10, col, 1.6, true)


func _draw_mist(w: float, h: float) -> void:
	for b in _beams:
		var pulse: float = 0.78 + 0.22 * sin(_time * float(b["speed"]) + float(b["phase"]))
		var a: float = float(b["alpha"]) * pulse * _fade_alpha
		var top_col := Color(0.78, 0.88, 0.86, a)
		var bot_col := Color(0.78, 0.88, 0.86, 0.0)
		var x0: float = float(b["x"])
		var bw: float = float(b["width"])
		var sk: float = float(b["skew"])
		draw_polygon(
			PackedVector2Array([
				Vector2(x0, 0.0),
				Vector2(x0 + bw, 0.0),
				Vector2(x0 + bw + sk * 1.35, h * 0.82),
				Vector2(x0 + sk, h * 0.82),
			]),
			PackedColorArray([top_col, top_col, bot_col, bot_col])
		)

	var haze_top := Color(0.65, 0.72, 0.74, 0.0)
	var haze_bot := Color(0.68, 0.75, 0.77, 0.18 * _fade_alpha)
	draw_polygon(
		PackedVector2Array([Vector2(0, h * 0.36), Vector2(w, h * 0.36), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([haze_top, haze_top, haze_bot, haze_bot])
	)

	for p in _particles:
		var phase_val: float = float(p["phase"])
		var rx: float = float(p["rx"])
		var ry: float = float(p["ry"])
		var breath: float = 0.8 + 0.2 * sin(phase_val)
		var col := Color(0.78, 0.84, 0.86, float(p["alpha"]) * breath * _fade_alpha)
		var center := Vector2(float(p["x"]), float(p["y"]) + sin(phase_val) * 12.0)
		draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx, col)
		draw_circle(Vector2.ZERO, rx * 0.6, Color(0.86, 0.90, 0.92, col.a * 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_moonlight(h: float) -> void:
	for b in _beams:
		var pulse: float = 0.78 + 0.22 * sin(_time * float(b["speed"]) + float(b["phase"]))
		var a: float = float(b["alpha"]) * pulse * _fade_alpha
		var top_col := Color(0.72, 0.80, 0.96, a)
		var bot_col := Color(0.72, 0.80, 0.96, 0.0)
		var x0: float = float(b["x"])
		var bw: float = float(b["width"])
		var sk: float = float(b["skew"])
		draw_polygon(
			PackedVector2Array([
				Vector2(x0, 0.0),
				Vector2(x0 + bw, 0.0),
				Vector2(x0 + bw + sk * 1.35, h * 0.85),
				Vector2(x0 + sk, h * 0.85),
			]),
			PackedColorArray([top_col, top_col, bot_col, bot_col])
		)

	for p in _particles:
		var tw: float = 0.45 + 0.55 * sin(float(p["phase"]))
		var a: float = float(p["alpha"]) * tw * _fade_alpha
		var r: float = float(p["radius"])
		var pos := Vector2(float(p["x"]), float(p["y"]))
		draw_circle(pos, r * 2.5, Color(0.70, 0.80, 1.0, a * 0.22))
		draw_circle(pos, r, Color(0.92, 0.95, 1.0, a))


func _draw_sunbeams(h: float) -> void:
	for b in _beams:
		var pulse: float = 0.8 + 0.2 * sin(_time * float(b["speed"]) + float(b["phase"]))
		var a: float = float(b["alpha"]) * pulse * _fade_alpha
		var top_col := Color(0.96, 0.86, 0.62, a)
		var bot_col := Color(0.96, 0.86, 0.62, 0.0)
		var x0: float = float(b["x"])
		var bw: float = float(b["width"])
		var sk: float = float(b["skew"])
		draw_polygon(
			PackedVector2Array([
				Vector2(x0, 0.0),
				Vector2(x0 + bw, 0.0),
				Vector2(x0 + bw + sk * 1.4, h * 0.88),
				Vector2(x0 + sk, h * 0.88),
			]),
			PackedColorArray([top_col, top_col, bot_col, bot_col])
		)

	for p in _particles:
		var tw: float = 0.4 + 0.6 * sin(float(p["phase"]))
		var a: float = float(p["alpha"]) * tw * _fade_alpha
		var r: float = float(p["radius"])
		var pos := Vector2(float(p["x"]), float(p["y"]))
		draw_circle(pos, r * 2.2, Color(0.95, 0.82, 0.48, a * 0.28))
		draw_circle(pos, r, Color(0.98, 0.95, 0.86, a))


func _draw_dust(w: float, h: float) -> void:
	var warmth := 0.82 + 0.18 * sin(_time * 1.6)
	draw_circle(Vector2(w * 0.50, h * 0.65), 340.0, Color(0.90, 0.52, 0.18, 0.055 * warmth * _fade_alpha))
	for p in _particles:
		var breath: float = 0.55 + 0.45 * sin(float(p["phase"]) * 1.4)
		var a: float = float(p["alpha"]) * breath * _fade_alpha
		var r: float = float(p["radius"])
		var pos := Vector2(float(p["x"]), float(p["y"]))
		draw_circle(pos, r * 1.8, Color(0.78, 0.66, 0.42, a * 0.22))
		draw_circle(pos, r, Color(0.94, 0.88, 0.76, a))
