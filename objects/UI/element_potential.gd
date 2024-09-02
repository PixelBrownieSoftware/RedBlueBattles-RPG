extends character_element_relationship_ui

func set_potential():
	$HBoxContainer/RichTextLabel.text = str(character.get_elemental_potential(element_subject))
	$HBoxContainer/TextureRect.texture = element_subject.icon
	
func set_affinity():
	$HBoxContainer/RichTextLabel.text = str(character.get_elemental_affinity(element_subject))
	$HBoxContainer/TextureRect.texture = element_subject.icon
