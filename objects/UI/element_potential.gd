extends character_element_relationship_ui
@export var affinity_texture : TextureRect
@export var weak_icon : Texture2D
@export var normal_icon : Texture2D
@export var resist_icon : Texture2D
@export var immune_icon : Texture2D
@export var reflect_icon : Texture2D


func set_potential():
	var potential : float = character.get_elemental_potential(element_subject)
	var txt : String = ""
	if potential > 0:
		txt = "[color=green]" + str(potential) + "[/color]"
	else: if potential == 0:
		txt = "[color=white]" + str(potential) + "[/color]"
	else: if potential < 0:
		txt = "[color=red]" + str(potential) + "[/color]"
	$HBoxContainer/TextureRect/Affinity/RichTextLabel.text = txt
	affinity_texture.visible = false
	$HBoxContainer/TextureRect.texture = element_subject.icon
	
func set_affinity():
	$HBoxContainer/TextureRect/Affinity/RichTextLabel.text = ""
	$HBoxContainer/TextureRect.texture = element_subject.icon
	affinity_texture.visible = true
	var affinity : float = character.get_elemental_affinity(element_subject)
	if affinity< 0:
		affinity_texture.texture = reflect_icon
	else: if affinity == 0:
		affinity_texture.texture = immune_icon
	else: if affinity > 0 && affinity < 1:
		affinity_texture.texture = resist_icon
	else: if affinity >= 1 && affinity < 2:
		affinity_texture.texture = normal_icon
	else: if affinity >= 2: 
		affinity_texture.texture = weak_icon
