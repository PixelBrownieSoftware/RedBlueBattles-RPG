extends character_element_relationship_ui

func set_potential():
	$RichTextLabel.text = element_subject.name + " " + str(character.get_elemental_potential(element_subject))
