extends Button
class_name button_character

@export var selected_character : battle_character_data
signal load_character(character : battle_character_data)
var status_effect_icon_prefab = preload("res://objects/UI/status_effect_icon.tscn")

func show_anim():
	disabled = true
	for button in $Status.get_children():
		button.queue_free()
	for status in selected_character.status_effects:
		var status_gui = status_effect_icon_prefab.instantiate()
		status_gui.set_icon(status)
		status_gui.update_status(status)
		$Status.add_child(status_gui)
	$AnimationPlayer.play("button_fade_in")
	
func enable_button():
	disabled = false
	
func hide_anim():
	$AnimationPlayer.play("button_fade_out")
	
func show_hp():
	$HealthBar.max_value = selected_character.max_health
	$HealthBar.value = selected_character.health

func _on_pressed():
	load_character.emit(selected_character)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "button_fade_in":
		disabled = false
