extends Panel
var selected_character
var status_effect_icon_prefab = preload("res://objects/UI/status_effect_icon.tscn")
var playing_backwards : bool = false

func on_character_exit():
	selected_character = null

func on_character_hover(character : battle_character_data):
	selected_character = character
	update_stuff()
	$CursorSound.play()

func show_menu():
	playing_backwards = false
	$AnimationPlayer.play("info_show")
	
func hide_menu():
	playing_backwards = true
	$AnimationPlayer.play_backwards("info_show")

func _process(delta: float) -> void:
	if selected_character != null:
		$RichTextLabel.text = selected_character.name
		$ProgressBar.max_value = selected_character.max_health
		$ProgressBar.min_value = 0
		$ProgressBar.value = selected_character.health
		$ProgressBar.visible = true
	else:
		$RichTextLabel.text = "Hover on a character and click to select."
		$ProgressBar.visible = false
		

func update_stuff():
	if selected_character == null:
		return
	for button in $Status.get_children():
		button.queue_free()
	for status in selected_character.status_effects:
		var status_gui = status_effect_icon_prefab.instantiate()
		status_gui.set_icon(status)
		status_gui.update_status(status)
		$Status.add_child(status_gui)

func back():
	update_stuff()
	selected_character = null
	hide_menu()
	
