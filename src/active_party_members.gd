extends Panel

func toggle_party_member(member):
	for button in $VBoxContainer.get_children():
		if button.character == member:
			if GlobalVariables.enabled_party_members[member]:
				if !button.visible:
					button.character = member
					button.visible = true
					break
			else:
				button.visible = false
				break
