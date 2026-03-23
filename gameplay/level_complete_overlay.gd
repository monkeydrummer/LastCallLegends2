class_name LevelCompleteOverlay
extends Control

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _total_score: Label = $Panel/Margin/VBox/TotalScore
@onready var _average: Label = $Panel/Margin/VBox/Average
@onready var _serves: Label = $Panel/Margin/VBox/Serves


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_results(level_display_name: String, total_score: int, serve_count: int, sum_serve_points: int) -> void:
	var name_text: String = level_display_name.strip_edges()
	if name_text.is_empty():
		name_text = "Complete"
	_title.text = "%s — Finished!" % name_text
	_total_score.text = "Total score: %d" % total_score
	var avg: float = 0.0
	if serve_count > 0:
		avg = float(sum_serve_points) / float(serve_count)
	_average.text = "Average per serve: %.1f pts" % avg
	_serves.text = "Guests served: %d" % serve_count
	show()
	get_viewport().gui_release_focus()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(Global.SCENE_MAIN_MENU)
