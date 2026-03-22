extends Node2D
class_name TapSlot

## Fired once the pour stream has fully stopped; fill_ratio is the final glass level.
signal pour_released(tap_index: int, fill_ratio: float)

@export var tap_index: int = 1
@export var pour_rate: float = 0.95
## After release: how fast the pour stream cuts off (higher = shorter tail). Glass fill keeps rising until this hits 0.
@export var stream_flow_decay_rate: float = 5.5

var _fill: float = 0.0
## 1 while pouring; decays after release so the stream tapers off without draining the glass.
var _stream_flow: float = 0.0
var _was_pressed: bool = false
## After button release: wait until the pour stream finishes decaying before scoring (final _fill).
var _awaiting_release_settle: bool = false
var _serve_feedback_locked: bool = false

var beer_color: Color = Color(1, 1, 1, 1)

@onready var _pour_stream: ColorRect = $PourStream
@onready var _glass: Control = $Glass
@onready var _liquid: ColorRect = $Glass/Liquid
@onready var _rating_label: Label = $RatingLabel


func _ready() -> void:
	_liquid.color = beer_color
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


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _serve_feedback_locked:
		if _stream_flow > 0.0:
			_fill += pour_rate * delta
			_stream_flow = maxf(_stream_flow - stream_flow_decay_rate * delta, 0.0)
		_was_pressed = false
		_update_visuals()
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
	_update_visuals()
	_try_emit_pour_settled()


func _update_visuals() -> void:
	var show_glass: bool = _fill > 0.001 or _stream_flow > 0.001
	_glass.visible = show_glass
	var stream_alpha: float = clampf(_stream_flow, 0.0, 1.0)
	_pour_stream.visible = stream_alpha > 0.001
	_pour_stream.color = Color(beer_color.r, beer_color.g, beer_color.b, 0.82 * stream_alpha)
	var max_h: float = _glass.size.y - 8.0
	var fill_h: float = clampf(_fill, 0.0, 1.2) * max_h
	_liquid.size.y = fill_h
	_liquid.position.y = _glass.size.y - fill_h - 4.0
