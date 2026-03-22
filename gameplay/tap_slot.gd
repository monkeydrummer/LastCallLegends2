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
var _foam_height: float = 0.0

@onready var _pour_stream_clip: Control = $PourStreamClip
@onready var _pour_stream_fill: ColorRect = $PourStreamClip/PourStreamFill
@onready var _glass: Control = $Glass
@onready var _liquid: ColorRect = $Glass/Liquid
@onready var _foam_head: ColorRect = $Glass/FoamHead
@onready var _rating_label: Label = $RatingLabel

var _bubble_drawer: _BubbleDrawer


func _ready() -> void:
	_liquid.color = beer_color
	_bubble_drawer = _BubbleDrawer.new()
	_glass.add_child(_bubble_drawer)
	_glass.move_child(_bubble_drawer, _foam_head.get_index())
	_bubble_drawer.z_index = 1
	_apply_stream_color()


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
	_foam_height = 0.0
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

	var max_h: float = _glass.size.y - 8.0
	var fill_h: float = clampf(_fill, 0.0, 1.2) * max_h
	var visual_h: float = maxf(0.0, fill_h)

	var foam_h: float = clampf(_foam_height, 0.0, maxf(0.0, visual_h))
	var body_h: float = maxf(0.0, visual_h - foam_h)

	var bottom_y: float = _glass.size.y - 4.0
	_liquid.size.y = body_h
	_liquid.position.y = bottom_y - body_h

	_foam_head.visible = show_glass and foam_h > 0.25
	_foam_head.size.y = foam_h
	_foam_head.position.y = bottom_y - body_h - foam_h


func _update_bubbles(delta: float) -> void:
	if _bubble_drawer == null:
		return
	var liquid_rect: Rect2 = Rect2(_liquid.position, _liquid.size)
	var pouring: bool = _stream_flow > 0.001
	var fr: float = clampf(_fill, 0.0, 1.0)
	_bubble_drawer.step(
		pouring,
		liquid_rect,
		fr,
		bubble_spawn_rate,
		bubble_rise_speed_min,
		bubble_rise_speed_max,
		bubble_radius_min,
		bubble_radius_max,
		bubble_wobble_px,
		delta
	)


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
		liquid_rect: Rect2,
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
		if liquid_rect.size.y < 0.5 or liquid_rect.size.x < 0.5:
			_bubbles.clear()
			queue_redraw()
			return
		if pouring:
			var mult: float = lerpf(0.45, 1.15, fill_ratio)
			_spawn_carry += delta * spawn_rate * mult
			while _spawn_carry >= 1.0:
				_spawn_carry -= 1.0
				_spawn_bubble(liquid_rect, spd_min, spd_max, r_min, r_max)
		var top_y: float = liquid_rect.position.y + 2.0
		var to_remove: Array[int] = []
		for i: int in _bubbles.size():
			var b: Dictionary = _bubbles[i]
			b["y"] -= b["spd"] * delta
			b["x"] = b["base_x"] + sin(_time * 5.0 + b["phase"]) * wobble
			if b["y"] < top_y:
				to_remove.append(i)
		for j: int in range(to_remove.size() - 1, -1, -1):
			_bubbles.remove_at(to_remove[j])
		queue_redraw()

	func _spawn_bubble(rect: Rect2, spd_min: float, spd_max: float, r_min: float, r_max: float) -> void:
		var pad: float = 2.0
		var x: float = _rng.randf_range(rect.position.x + pad, rect.position.x + rect.size.x - pad)
		var y: float = rect.position.y + rect.size.y - _rng.randf_range(1.0, 6.0)
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
