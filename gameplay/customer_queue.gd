extends Node2D
class_name CustomerQueue

const MAX_CUSTOMERS: int = 5

signal queue_changed()
signal front_patience_changed(ratio: float)
signal customer_left_angry()
signal customer_served(rating: String, points_awarded: int)

const CUSTOMER_SCENE: PackedScene = preload("res://gameplay/customer/customer.tscn")

var _customers: Array = []
var _spawn_timer: float = 0.0

@export var spawn_interval: float = 5.5
## After a successful serve, try to spawn the next customer after this delay (seconds), ignoring spawn cooldown.
@export var spawn_after_serve_delay: float = 0.2
var _patience_for_next: float = 28.0
var _serve_spawn_countdown: float = 0.0
var _spawn_enabled: bool = true

## One position per bar stand; each customer picks a random free slot so sprites do not overlap.
## Spaced for ~300px-wide portraits across a 1280-wide viewport; Y is local to CustomerQueue.
@export var customer_slot_positions: Array[Vector2] = [
	Vector2(148, 130),
	Vector2(393, 130),
	Vector2(638, 130),
	Vector2(883, 130),
	Vector2(1128, 130),
]


func configure(patience_seconds: float) -> void:
	_patience_for_next = patience_seconds


func set_spawn_enabled(enabled: bool) -> void:
	_spawn_enabled = enabled


func clear_all_customers() -> void:
	for c in _customers:
		if is_instance_valid(c):
			c.queue_free()
	_customers.clear()
	_relayout_queue()
	queue_changed.emit()


func _ready() -> void:
	_spawn_timer = 1.5


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_spawn_timer -= delta
	_process_serve_spawn_countdown(delta)
	if _spawn_enabled and _customers.size() < MAX_CUSTOMERS and _spawn_timer <= 0.0:
		_spawn_customer()
		_spawn_timer = spawn_interval
	if _customers.is_empty():
		return
	for cust in _customers:
		cust.tick_patience(delta)
	_update_customer_wait_bars()
	front_patience_changed.emit(_customers[0].get_patience_ratio())
	_remove_expired_customers()


func _process_serve_spawn_countdown(delta: float) -> void:
	if _serve_spawn_countdown <= 0.0:
		return
	_serve_spawn_countdown -= delta
	if _serve_spawn_countdown > 0.0:
		return
	_serve_spawn_countdown = 0.0
	if not _spawn_enabled:
		return
	if _customers.size() >= MAX_CUSTOMERS:
		return
	_spawn_customer()


func _spawn_customer() -> void:
	if not _spawn_enabled:
		return
	var c = CUSTOMER_SCENE.instantiate()
	var beer: int = randi_range(1, 5)
	var slot: int = _pick_random_free_slot()
	c.bar_slot_index = slot
	c.position = _position_for_bar_slot(slot)
	add_child(c)
	c.set_portrait_texture(_pick_unused_portrait_texture())
	c.setup_order(beer, _patience_for_next)
	_customers.append(c)
	_update_customer_wait_bars()
	queue_changed.emit()


func _bar_slot_count() -> int:
	if customer_slot_positions.is_empty():
		return 0
	return mini(customer_slot_positions.size(), MAX_CUSTOMERS)


func _position_for_bar_slot(slot: int) -> Vector2:
	if customer_slot_positions.is_empty():
		return Vector2(640, 130)
	var last: int = customer_slot_positions.size() - 1
	var i: int = clampi(slot, 0, last)
	return customer_slot_positions[i]


func _pick_random_free_slot() -> int:
	var n: int = _bar_slot_count()
	if n <= 0:
		return 0
	var used: Array[bool] = []
	used.resize(n)
	for c in _customers:
		var si: int = c.bar_slot_index
		if si >= 0 and si < n:
			used[si] = true
	var free_slots: Array[int] = []
	for s in range(n):
		if not used[s]:
			free_slots.append(s)
	if free_slots.is_empty():
		return 0
	return free_slots[randi() % free_slots.size()]


func _pick_unused_portrait_texture() -> Texture2D:
	var pool: Array[Texture2D] = BarCustomer.PORTRAIT_TEXTURES
	var used: Array[bool] = []
	used.resize(pool.size())
	for cust in _customers:
		if not is_instance_valid(cust):
			continue
		var t: Texture2D = cust.get_portrait_texture()
		if t == null:
			continue
		for i in range(pool.size()):
			if pool[i] == t:
				used[i] = true
				break
	var free_indices: Array[int] = []
	for i in range(pool.size()):
		if not used[i]:
			free_indices.append(i)
	if free_indices.is_empty():
		return pool[randi() % pool.size()]
	return pool[free_indices[randi() % free_indices.size()]]


func _relayout_queue() -> void:
	_update_customer_wait_bars()


func _update_customer_wait_bars() -> void:
	for cust in _customers:
		if not cust.has_method("set_wait_bar_ratio"):
			continue
		cust.set_wait_bar_ratio(cust.get_patience_ratio())


func _remove_expired_customers() -> void:
	var i: int = 0
	var removed_any: bool = false
	while i < _customers.size():
		if _customers[i].patience_remaining <= 0.0:
			var c = _customers[i]
			c.queue_free()
			_customers.remove_at(i)
			removed_any = true
			customer_left_angry.emit()
		else:
			i += 1
	if removed_any:
		_relayout_queue()
		queue_changed.emit()


func get_front_order_beer() -> int:
	if _customers.is_empty():
		return -1
	return _customers[0].order_beer_index


func get_front_patience_ratio() -> float:
	if _customers.is_empty():
		return 1.0
	return _customers[0].get_patience_ratio()


func get_patience_ratio_at_index(index: int) -> float:
	if index < 0 or index >= _customers.size():
		return 1.0
	return _customers[index].get_patience_ratio()


func get_customer_at_index(index: int) -> BarCustomer:
	if index < 0 or index >= _customers.size():
		return null
	return _customers[index] as BarCustomer


## First in line (lowest index) who ordered this beer — FIFO among matching orders.
func find_first_index_wanting_beer(beer_index: int) -> int:
	for i in range(_customers.size()):
		if _customers[i].awaiting_serve_feedback:
			continue
		if _customers[i].order_beer_index == beer_index:
			return i
	return -1


func mark_awaiting_serve_feedback(index: int) -> void:
	if index < 0 or index >= _customers.size():
		return
	_customers[index].awaiting_serve_feedback = true


func try_complete_serve_feedback_for_customer(customer: BarCustomer, rating: String, points_awarded: int) -> void:
	if not is_instance_valid(customer):
		return
	var idx: int = _customers.find(customer)
	if idx < 0:
		return
	if not customer.awaiting_serve_feedback:
		return
	complete_order_at_index(idx, rating, points_awarded)


func complete_order_at_index(index: int, rating: String, points_awarded: int) -> void:
	if index < 0 or index >= _customers.size():
		return
	var c = _customers[index]
	c.queue_free()
	_customers.remove_at(index)
	_relayout_queue()
	customer_served.emit(rating, points_awarded)
	queue_changed.emit()
	_serve_spawn_countdown = spawn_after_serve_delay
