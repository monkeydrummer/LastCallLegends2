extends Control

@onready var _bg: TextureRect = $BackgroundLayer/Background
@onready var _queue: CustomerQueue = $World/CustomerQueue
@onready var _bar_taps: BarTaps = $TapsLayer/BarTaps
@onready var _score_label: Label = $HUD/Root/VBox/ScoreLabel
@onready var _serves_label: Label = $HUD/Root/VBox/ServesProgress
@onready var _order_label: Label = $HUD/Root/VBox/OrderHint
@onready var _last_rating: Label = $HUD/Root/VBox/LastRating
@onready var _level_complete_overlay: LevelCompleteOverlay = $LevelCompleteLayer/LevelComplete

var _score: int = 0
var _target_serves: int = 15
var _serves_completed: int = 0
var _sum_serve_points: int = 0
var _level_complete: bool = false

const WRONG_TAP_PENALTY: int = 5
const ANGRY_PENALTY: int = 25
const POINTS_OK: int = 40
const POINTS_GREAT: int = 70
const POINTS_PERFECT: int = 110
const POINTS_OVERFLOW: int = 15
const SPEED_BONUS_MAX: int = 25
const SERVE_FEEDBACK_DURATION: float = 1.0

const PAUSE_SCENE := preload("res://paused/paused.tscn")


func _ready() -> void:
	var tex: Texture2D = Session.pick_background_texture()
	if tex != null:
		_bg.texture = tex
	var ld: LevelData = Session.get_level_data()
	if ld != null:
		_queue.configure(ld.wait_time_seconds)
		_target_serves = maxi(1, ld.customers_to_serve)
	_bar_taps.apply_palette()
	for slot in _bar_taps.get_slots():
		slot.pour_released.connect(_on_pour_released)
	_queue.customer_left_angry.connect(_on_angry)
	_queue.queue_changed.connect(_on_queue_changed)
	_queue.customer_served.connect(_on_customer_served)
	_on_queue_changed()


func _on_pour_released(tap_index: int, fill_ratio: float) -> void:
	if _level_complete:
		return
	var idx: int = _queue.find_first_index_wanting_beer(tap_index)
	if idx < 0:
		if _queue.get_front_order_beer() < 0:
			return
		_clear_tap(tap_index)
		_score = maxi(0, _score - WRONG_TAP_PENALTY)
		_update_hud()
		return
	if fill_ratio < 0.85:
		return
	var rating: String = ""
	var points: int = 0
	if fill_ratio > 1.02:
		rating = "overflow"
		points = POINTS_OVERFLOW
	elif fill_ratio >= 0.96:
		rating = "perfect"
		points = POINTS_PERFECT
	elif fill_ratio >= 0.91:
		rating = "great"
		points = POINTS_GREAT
	else:
		rating = "ok"
		points = POINTS_OK
	var speed_bonus: int = int(SPEED_BONUS_MAX * _queue.get_patience_ratio_at_index(idx))
	points += speed_bonus
	var served: BarCustomer = _queue.get_customer_at_index(idx)
	if served == null:
		return
	_score += points
	_queue.mark_awaiting_serve_feedback(idx)
	var slot: TapSlot = _slot_for_tap_index(tap_index)
	if slot != null:
		slot.set_serve_feedback_locked(true)
		slot.show_serve_rating(rating, points)
	_last_rating.text = "%s +%d" % [rating, points]
	_update_hud()
	get_tree().create_timer(SERVE_FEEDBACK_DURATION).timeout.connect(
		_on_serve_feedback_finished.bind(tap_index, served, rating, points)
	)


func _on_serve_feedback_finished(tap_index: int, served: BarCustomer, rating: String, points_awarded: int) -> void:
	var slot: TapSlot = _slot_for_tap_index(tap_index)
	if slot != null:
		slot.set_serve_feedback_locked(false)
		slot.hide_serve_rating()
	_clear_tap(tap_index)
	if _level_complete:
		return
	_queue.try_complete_serve_feedback_for_customer(served, rating, points_awarded)


func _slot_for_tap_index(tap_index: int) -> TapSlot:
	for s in _bar_taps.get_slots():
		if s.tap_index == tap_index:
			return s as TapSlot
	return null


func _clear_tap(tap_index: int) -> void:
	for s in _bar_taps.get_slots():
		if s.tap_index == tap_index:
			s.clear_fill()
			break


func _on_angry() -> void:
	_score = maxi(0, _score - ANGRY_PENALTY)
	_last_rating.text = "Left angry!"
	_update_hud()


func _on_queue_changed() -> void:
	if _level_complete:
		return
	var b: int = _queue.get_front_order_beer()
	if b < 0:
		_order_label.text = "Order: —"
	else:
		_order_label.text = "Order: Beer %d" % b
	_update_hud()


func _on_customer_served(_rating: String, points_awarded: int) -> void:
	if _level_complete:
		return
	_serves_completed += 1
	_sum_serve_points += points_awarded
	_update_hud()
	if _serves_completed >= _target_serves:
		_finish_level()


func _finish_level() -> void:
	_level_complete = true
	_queue.set_spawn_enabled(false)
	_queue.clear_all_customers()
	_order_label.text = "Order: —"
	var ld: LevelData = Session.get_level_data()
	var level_name: String = ""
	if ld != null:
		level_name = ld.display_name
	_level_complete_overlay.show_results(level_name, _score, _serves_completed, _sum_serve_points)
	get_tree().paused = true


func _update_hud() -> void:
	_score_label.text = "Score: %d" % _score
	_serves_label.text = "Serves: %d / %d" % [_serves_completed, _target_serves]


func _input(event: InputEvent) -> void:
	if _level_complete:
		return
	if event.is_action_released("pause"):
		call_deferred("_open_pause_overlay")


func _open_pause_overlay() -> void:
	if _level_complete:
		return
	if get_tree().paused:
		return
	if get_node_or_null("PauseOverlay") != null:
		return
	add_child(PAUSE_SCENE.instantiate())
	get_tree().paused = true
