extends Button
var is_on = false

func _on_pressed() -> void:
	if !is_on:
		$"../Character stats".visible = true
		is_on = true
		text = "Back"
	else:
		$"../Character stats".visible = false
		is_on = false
		text = "Analyse"

func force_off():
	$"../Character stats".visible = false
	visible = false
	is_on = false
	text = "Analyse"
