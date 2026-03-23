extends Node2D
class_name TapSlot

## Fired once the pour stream has fully stopped; fill_ratio is the final glass level.
signal pour_released(tap_index: int, fill_ratio: float)

@export var tap_index: int = 1
@export var pour_rate: float = 0.95
## After release: how fast the pour stream cuts off (higher = shorter tail). Glass fill keeps rising until this hits 0.
@export var stream_flow_decay_rate: float = 5.5
## How fast the pour stream grows from the tap (0–1) each second while flowing.
@export var stream_reveal_speed: float = 8.0
## How fast the stream reveal snaps back when flow stops.
@export var stream_reveal_decay_speed: float = 16.0
## Side-to-side sway of the pour stream while flowing (rotation about the tap).
@export var pour_stream_sway_hz: float = 2.75
@export var pour_stream_sway_max_deg: float = 1.5

## Inner cup width at the top (wider) vs bottom (narrower), in glass local pixels.
@export var glass_inner_top_w: float = 40.0
@export var glass_inner_bottom_w: float = 32.0
## Outer rim width at the bottom of the cup (top uses full glass width).
@export var glass_outer_bottom_w: float = 36.0
@export var glass_back_color: Color = Color(0.85, 0.9, 0.95, 0.38)
@export var glass_rim_color: Color = Color(0.78, 0.86, 0.94, 0.95)
@export var glass_highlight_color: Color = Color(1, 1, 1, 0.42)

## Bubbles rise through the liquid while pouring (spawn rate scales slightly with fill).
@export var bubble_spawn_rate: float = 14.0
@export var bubble_rise_speed_min: float = 38.0
@export var bubble_rise_speed_max: float = 82.0
@export var bubble_radius_min: float = 1.0
@export var bubble_radius_max: float = 2.4
@export var bubble_wobble_px: float = 1.25

@export var foam_min_px: float = 1.5
@export var foam_max_px: float = 14.0
## Added to foam floor when glass has more fill (0..1).
@export var foam_fill_bonus: float = 2.0
@export var foam_build_rate: float = 28.0
@export var foam_decay_rate: float = 22.0

var _fill: float = 0.0
## 1 while pouring; decays after release so the stream tapers off without draining the glass.
var _stream_flow: float = 0.0
var _was_pressed: bool = false
## After button release: wait until the pour stream finishes decaying before scoring (final _fill).
var _awaiting_release_settle: bool = false
var _serve_feedback_locked: bool = false

var beer_color: Color = Color(1, 1, 1, 1)

var _stream_reveal: float = 0.0
var _prev_stream_flow: float = 0.0
var _stream_sway_t: float = 0.0
var _foam_height: float = 0.0

@onready var _pour_stream_clip: Control = $PourStreamClip
@onready var _pour_stream_fill: ColorRect = $PourStreamClip/PourStreamFill
@onready var _glass: Control = $Glass
@onready var _glass_back: Polygon2D = $Glass/GlassBack
@onready var _liquid: Polygon2D = $Glass/Liquid
@onready var _foam_head: Polygon2D = $Glass/FoamHead
@onready var _rating_label: Label = $RatingLabel

var _bubble_drawer: _BubbleDrawer
var _glass_front: _GlassFront


func _ready() -> void:
	_liquid.color = beer_color
	_glass_back.color = glass_back_color
	_bubble_drawer = _BubbleDrawer.new()
	_glass.add_child(_bubble_drawer)
	_glass.move_child(_bubble_drawer, _foam_head.get_index())
	_bubble_drawer.z_index = 1
	_glass_front = _GlassFront.new()
	_glass_front._slot = self
	_glass.add_child(_glass_front)
	_glass_front.z_index = 2
	_apply_stream_color()


func _cup_bottom_y() -> float:
	return _glass.size.y - 4.0


func _glass_taper_t(y: float) -> float:
	var cup_h: float = _cup_bottom_y()
	if cup_h <= 0.001:
		return 0.0
	return clampf(y / cup_h, 0.0, 1.0)


func _inner_width_at_y(y: float) -> float:
	return lerpf(glass_inner_top_w, glass_inner_bottom_w, _glass_taper_t(y))


func _inner_x_left(y: float) -> float:
	return (_glass.size.x - _inner_width_at_y(y)) * 0.5


func _inner_x_right(y: float) -> float:
	return _inner_x_left(y) + _inner_width_at_y(y)


func _outer_width_at_y(y: float) -> float:
	return lerpf(_glass.size.x, glass_outer_bottom_w, _glass_taper_t(y))


func _outer_x_left(y: float) -> float:
	return (_glass.size.x - _outer_width_at_y(y)) * 0.5


func _outer_x_right(y: float) -> float:
	return _outer_x_left(y) + _outer_width_at_y(y)


func set_beer_color(c: Color) -> void:
	beer_color = c
	if is_node_ready():
		_liquid.color = c
		_apply_stream_color()


func clear_fill() -> void:
	_fill = 0.0
	_stream_flow = 0.0
	_awaiting_release_settle = false
	_stream_reveal = 0.0
	_prev_stream_flow = 0.0
	_stream_sway_t = 0.0
	_foam_height = 0.0
	if is_node_ready():
		_pour_stream_clip.rotation = 0.0
	if _bubble_drawer != null:
		_bubble_drawer.clear_bubbles()
	_update_visuals()


func set_serve_feedback_locked(locked: bool) -> void:
	_serve_feedback_locked = locked
	if locked:
		_was_pressed = false


func show_serve_rating(rating: String, points: int) -> void:
	_rating_label.text = "%s +%d" % [rating.capitalize(), points]
	_rating_label.visible = true


func hide_serve_rating() -> void:
	_rating_label.visible = false
	_rating_label.text = ""


func get_fill_ratio() -> float:
	return _fill


func _apply_stream_color() -> void:
	_update_visuals()


func _try_emit_pour_settled() -> void:
	if not _awaiting_release_settle:
		return
	if _stream_flow > 0.001:
		return
	_awaiting_release_settle = false
	pour_released.emit(tap_index, _fill)


func _update_juice(delta: float) -> void:
	if _stream_flow > 0.001:
		if _prev_stream_flow <= 0.001:
			_stream_reveal = 0.0
		_stream_reveal = move_toward(_stream_reveal, 1.0, stream_reveal_speed * delta)
		_stream_sway_t += delta
	else:
		_stream_reveal = move_toward(_stream_reveal, 0.0, stream_reveal_decay_speed * delta)

	var fill_ratio: float = clampf(_fill, 0.0, 1.0)
	var foam_target: float = lerpf(foam_min_px, foam_max_px, fill_ratio)
	var foam_floor: float = foam_min_px + foam_fill_bonus * fill_ratio

	if _stream_flow > 0.001:
		_foam_height = move_toward(_foam_height, foam_target, foam_build_rate * delta)
	else:
		_foam_height = move_toward(_foam_height, foam_floor, foam_decay_rate * delta)

	_prev_stream_flow = _stream_flow


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _serve_feedback_locked:
		if _stream_flow > 0.0:
			_fill += pour_rate * delta
			_stream_flow = maxf(_stream_flow - stream_flow_decay_rate * delta, 0.0)
		_was_pressed = false
		_update_juice(delta)
		_update_visuals()
		_update_bubbles(delta)
		return
	var action_name: StringName = "tap_%d" % tap_index
	var pressed: bool = Input.is_action_pressed(action_name)
	if pressed:
		_awaiting_release_settle = false
		_fill += pour_rate * delta
		_stream_flow = 1.0
	else:
		if _was_pressed and not pressed:
			_awaiting_release_settle = true
		if _stream_flow > 0.0:
			_fill += pour_rate * delta
			_stream_flow = maxf(_stream_flow - stream_flow_decay_rate * delta, 0.0)
	_was_pressed = pressed
	_update_juice(delta)
	_update_visuals()
	_update_bubbles(delta)
	_try_emit_pour_settled()


func _update_visuals() -> void:
	var show_glass: bool = _fill > 0.001 or _stream_flow > 0.001
	_glass.visible = show_glass
	var stream_alpha: float = clampf(_stream_flow, 0.0, 1.0)
	_pour_stream_clip.visible = stream_alpha > 0.001
	var clip_h: float = _pour_stream_clip.size.y
	if clip_h <= 0.0:
		clip_h = 100.0
	_pour_stream_fill.offset_bottom = clip_h * _stream_reveal
	_pour_stream_fill.color = Color(beer_color.r, beer_color.g, beer_color.b, 0.82 * stream_alpha)

	var sw: float = _pour_stream_clip.size.x
	if sw > 0.0:
		_pour_stream_clip.pivot_offset = Vector2(sw * 0.5, 0.0)
	var sway_rad: float = deg_to_rad(pour_stream_sway_max_deg) * sin(_stream_sway_t * TAU * pour_stream_sway_hz) * stream_alpha
	_pour_stream_clip.rotation = sway_rad

	var max_h: float = _glass.size.y - 8.0
	var fill_h: float = clampf(_fill, 0.0, 1.2) * max_h
	var visual_h: float = maxf(0.0, fill_h)

	var foam_h: float = clampf(_foam_height, 0.0, maxf(0.0, visual_h))
	var body_h: float = maxf(0.0, visual_h - foam_h)

	var bottom_y: float = _cup_bottom_y()
	var body_top_y: float = bottom_y - body_h
	var foam_top_y: float = body_top_y - foam_h

	_glass_back.visible = show_glass
	_glass_back.color = glass_back_color
	var gbtl: Vector2 = Vector2(_inner_x_left(0.0), 0.0)
	var gbtr: Vector2 = Vector2(_inner_x_right(0.0), 0.0)
	var gbbr: Vector2 = Vector2(_inner_x_right(bottom_y), bottom_y)
	var gbbl: Vector2 = Vector2(_inner_x_left(bottom_y), bottom_y)
	_glass_back.polygon = PackedVector2Array([gbtl, gbtr, gbbr, gbbl])

	if body_h > 0.25:
		var lbl: Vector2 = Vector2(_inner_x_left(bottom_y), bottom_y)
		var lbr: Vector2 = Vector2(_inner_x_right(bottom_y), bottom_y)
		var ltr: Vector2 = Vector2(_inner_x_right(body_top_y), body_top_y)
		var ltl: Vector2 = Vector2(_inner_x_left(body_top_y), body_top_y)
		_liquid.visible = true
		_liquid.polygon = PackedVector2Array([lbl, lbr, ltr, ltl])
	else:
		_liquid.visible = false
		_liquid.polygon = PackedVector2Array()

	_foam_head.visible = show_glass and foam_h > 0.25
	if _foam_head.visible:
		var fbl: Vector2 = Vector2(_inner_x_left(body_top_y), body_top_y)
		var fbr: Vector2 = Vector2(_inner_x_right(body_top_y), body_top_y)
		var ftr: Vector2 = Vector2(_inner_x_right(foam_top_y), foam_top_y)
		var ftl: Vector2 = Vector2(_inner_x_left(foam_top_y), foam_top_y)
		_foam_head.polygon = PackedVector2Array([fbl, fbr, ftr, ftl])
	else:
		_foam_head.polygon = PackedVector2Array()

	if _glass_front != null:
		_glass_front.visible = show_glass
		_glass_front.queue_redraw()


func _update_bubbles(delta: float) -> void:
	if _bubble_drawer == null:
		return
	var bottom_y: float = _cup_bottom_y()
	var max_h: float = _glass.size.y - 8.0
	var fill_h: float = clampf(_fill, 0.0, 1.2) * max_h
	var visual_h: float = maxf(0.0, fill_h)
	var foam_h: float = clampf(_foam_height, 0.0, maxf(0.0, visual_h))
	var body_h: float = maxf(0.0, visual_h - foam_h)
	var body_top_y: float = bottom_y - body_h
	var pouring: bool = _stream_flow > 0.001
	var fr: float = clampf(_fill, 0.0, 1.0)
	_bubble_drawer.step(
		pouring,
		self,
		body_top_y,
		bottom_y,
		fr,
		bubble_spawn_rate,
		bubble_rise_speed_min,
		bubble_rise_speed_max,
		bubble_radius_min,
		bubble_radius_max,
		bubble_wobble_px,
		delta
	)


class _GlassFront extends Node2D:
	var _slot: TapSlot

	func _draw() -> void:
		if _slot == null:
			return
		var g: Control = _slot._glass
		if not g.visible:
			return
		var bottom_y: float = _slot._cup_bottom_y()
		if bottom_y < 1.0:
			return
		var o_tl: Vector2 = Vector2(_slot._outer_x_left(0.0), 0.0)
		var o_tr: Vector2 = Vector2(_slot._outer_x_right(0.0), 0.0)
		var o_br: Vector2 = Vector2(_slot._outer_x_right(bottom_y), bottom_y)
		var o_bl: Vector2 = Vector2(_slot._outer_x_left(bottom_y), bottom_y)
		var rim: Color = _slot.glass_rim_color
		var hi: Color = _slot.glass_highlight_color
		var outline: PackedVector2Array = PackedVector2Array([o_tl, o_tr, o_br, o_bl, o_tl])
		draw_polyline(outline, rim, 2.25, true)
		var steps: int = 14
		for i: int in range(steps):
			var t1: float = float(i) / float(steps)
			var t2: float = float(i + 1) / float(steps)
			var y1: float = t1 * bottom_y * 0.88
			var y2: float = t2 * bottom_y * 0.88
			var x1: float = _slot._outer_x_left(y1) + 1.1
			var x2: float = _slot._outer_x_left(y2) + 1.1
			var a1: float = lerpf(0.12, hi.a, 1.0 - t1 * 0.35)
			var a2: float = lerpf(0.12, hi.a, 1.0 - t2 * 0.35)
			draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(hi.r, hi.g, hi.b, a1 * 0.5 + a2 * 0.5), 2.0)


class _BubbleDrawer extends Node2D:
	var _bubbles: Array[Dictionary] = []
	var _spawn_carry: float = 0.0
	var _time: float = 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()

	func clear_bubbles() -> void:
		_bubbles.clear()
		_spawn_carry = 0.0
		queue_redraw()

	func step(
		pouring: bool,
		slot: TapSlot,
		body_top_y: float,
		bottom_y: float,
		fill_ratio: float,
		spawn_rate: float,
		spd_min: float,
		spd_max: float,
		r_min: float,
		r_max: float,
		wobble: float,
		delta: float
	) -> void:
		_time += delta
		var pad: float = 2.0
		if bottom_y - body_top_y < 0.5 or slot._glass.size.x < 0.5:
			_bubbles.clear()
			queue_redraw()
			return
		if pouring:
			var mult: float = lerpf(0.45, 1.15, fill_ratio)
			_spawn_carry += delta * spawn_rate * mult
			while _spawn_carry >= 1.0:
				_spawn_carry -= 1.0
				_spawn_bubble(slot, bottom_y, pad, spd_min, spd_max, r_min, r_max)
		var top_y: float = body_top_y + 2.0
		var to_remove: Array[int] = []
		for i: int in _bubbles.size():
			var b: Dictionary = _bubbles[i]
			b["y"] -= b["spd"] * delta
			var wx: float = b["base_x"] + sin(_time * 5.0 + b["phase"]) * wobble
			var xl: float = slot._inner_x_left(b["y"]) + pad
			var xr: float = slot._inner_x_right(b["y"]) - pad
			b["x"] = clampf(wx, xl, xr)
			if b["y"] < top_y:
				to_remove.append(i)
		for j: int in range(to_remove.size() - 1, -1, -1):
			_bubbles.remove_at(to_remove[j])
		queue_redraw()

	func _spawn_bubble(slot: TapSlot, bottom_y: float, pad: float, spd_min: float, spd_max: float, r_min: float, r_max: float) -> void:
		var xl: float = slot._inner_x_left(bottom_y) + pad
		var xr: float = slot._inner_x_right(bottom_y) - pad
		var x: float = _rng.randf_range(xl, xr)
		var y: float = bottom_y - _rng.randf_range(1.0, 6.0)
		_bubbles.append({
			"base_x": x,
			"x": x,
			"y": y,
			"spd": _rng.randf_range(spd_min, spd_max),
			"r": _rng.randf_range(r_min, r_max),
			"phase": _rng.randf() * TAU,
		})

	func _draw() -> void:
		for b: Dictionary in _bubbles:
			var c: Color = Color(1, 1, 1, 0.38)
			draw_circle(Vector2(b["x"], b["y"]), b["r"], c)
			draw_arc(Vector2(b["x"], b["y"]), b["r"] * 0.65, 0.0, TAU, 10, Color(1, 1, 1, 0.2), 0.8, true)
