extends Node

@export var cost : int
@export var is_open : bool = false
@export var unlocker_button : Button
@export var unlocker_text : RichTextLabel
@export var unlocker : Control

func unlock():
	GlobalVariables.expereince_score -= cost
	is_open = true
	unlocker.visible = false

func on_tab_open(tab: int):
	if !is_open:
		unlocker_text.text = "[center]Cost: " + str(cost) + "[/center]"
		unlocker_button.pressed.connect(unlock)
		unlocker_button.disabled = cost > GlobalVariables.expereince_score
		unlocker.visible = true
		for button : Button in get_children():
			button.disabled = true
