extends Control


func _ready() -> void:
	var sfx: Node = get_parent().get_parent().get_node_or_null("SelectSfx")
	if sfx != null:
		Sound.play_sfx(sfx)
	$PauseOptions.focus()


func _input(event: InputEvent) -> void:
	if event.is_action_released("pause"):
		call_deferred("_resume")


func _resume() -> void:
	get_tree().paused = false
	get_parent().queue_free()
