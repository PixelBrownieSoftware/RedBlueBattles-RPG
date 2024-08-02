extends Panel

var buttons : Array[Button]

func reset_buttons():
	for button in buttons:
		button.visible = false
		

func _ready():
	for partyColumn in $VBoxContainer.get_children():
		for button in partyColumn.get_children():
			buttons.append(button)
	reset_buttons()
	
func activate():
	reset_buttons()
	var ind : int = 0
	for chara in PartyMembers.get_children():
		buttons[chara.get_index()].visible = true
		buttons[chara.get_index()].text = chara.name
		buttons[chara.get_index()].character = chara


func close_menu(chara):
	visible=false
