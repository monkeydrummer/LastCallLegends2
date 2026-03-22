extends Node2D
class_name BarCustomer

const PORTRAIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/customers/customer_portrait1_300.png"),
	preload("res://assets/customers/customer_portrait2_300.png"),
	preload("res://assets/customers/customer_portrait3_300.png"),
	preload("res://assets/customers/customer_portrait4_300.png"),
	preload("res://assets/customers/customer_portrait5_300.png"),
	preload("res://assets/customers/customer_portrait6_300.png"),
	preload("res://assets/customers/customer_portrait7_300.png"),
	preload("res://assets/customers/customer_portrait8_300.png"),
]

const PORTRAIT_WIDTH_PX: float = 300.0

var order_beer_index: int = 1
var bar_slot_index: int = -1
var awaiting_serve_feedback: bool = false
var patience_max: float = 30.0
var patience_remaining: float = 30.0

@onready var _portrait: Sprite2D = $Portrait
@onready var _order_label: Label = $OrderBubble/Label
@onready var _wait_bar: ProgressBar = $WaitBar


func _ready() -> void:
	set_wait_bar_ratio(1.0)


func get_portrait_texture() -> Texture2D:
	if _portrait == null:
		return null
	return _portrait.texture


func set_portrait_texture(tex: Texture2D) -> void:
	_portrait.texture = tex
	var tw: float = float(_portrait.texture.get_width())
	var s: float = PORTRAIT_WIDTH_PX / tw
	_portrait.scale = Vector2(s, s)
	var half_h: float = float(_portrait.texture.get_height()) * s * 0.5
	_portrait.position = Vector2(0.0, -half_h)


func setup_order(beer: int, patience: float) -> void:
	order_beer_index = beer
	patience_max = patience
	patience_remaining = patience
	_order_label.text = "Beer %d" % beer


func tick_patience(delta: float) -> void:
	if awaiting_serve_feedback:
		return
	patience_remaining -= delta


func get_patience_ratio() -> float:
	if patience_max <= 0.0:
		return 0.0
	return clampf(patience_remaining / patience_max, 0.0, 1.0)


func set_wait_bar_ratio(ratio: float) -> void:
	if _wait_bar == null:
		return
	_wait_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
