extends Button

@export var gameplay_scene: PackedScene
@export var level_data: LevelData

func _on_pressed() -> void:
	if level_data != null:
		Session.set_level(level_data)
	if gameplay_scene != null:
		get_tree().change_scene_to_packed(gameplay_scene)
