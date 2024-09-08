extends Node2D
func _ready() -> void:
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
