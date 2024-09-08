extends Node2D
var save_path = OS.get_user_data_dir() + "/save.rbb"

func _ready() -> void:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file != null:
		$"Control/Load game".visible = true
	else:
		$"Control/Load game".visible = false
		
	await FadeScene.fade_bg(Color(Color.BLACK, 0), 0.5)

func new_game():
	$"Control/Load game".disabled = true
	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file("res://scenes/overworld_scene.tscn")

func load_game():
	$"Control/Load game".disabled = true
	SaveSystem.load_game()
	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file("res://scenes/overworld_scene.tscn")
