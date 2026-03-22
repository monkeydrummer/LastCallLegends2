extends Node2D
class_name BarTaps

## Resource with script beer_style_palette.gd (get_color_for_tap).
@export var beer_palette: Resource


func _ready() -> void:
	_apply_palette()


func apply_palette() -> void:
	_apply_palette()


func _apply_palette() -> void:
	if beer_palette == null or not beer_palette.has_method("get_color_for_tap"):
		return
	for child in get_children():
		if child.has_method("set_beer_color") and child.has_method("get_fill_ratio"):
			var idx: Variant = child.get("tap_index")
			if idx == null:
				continue
			child.set_beer_color(beer_palette.get_color_for_tap(int(idx)))


func get_slots() -> Array:
	var out: Array = []
	for child in get_children():
		if child.has_method("set_beer_color") and child.has_method("get_fill_ratio"):
			out.append(child)
	return out
