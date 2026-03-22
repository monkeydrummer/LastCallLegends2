extends Node

var current_level_data: LevelData

func set_level(level: LevelData) -> void:
	current_level_data = level

func get_level_data() -> LevelData:
	return current_level_data

func pick_background_texture() -> Texture2D:
	var ld: LevelData = current_level_data
	if ld == null:
		return null
	if not ld.background_pool.is_empty():
		return ld.background_pool.pick_random()
	if ld.background_texture != null:
		return ld.background_texture
	return null
