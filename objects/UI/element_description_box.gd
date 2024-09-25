extends Panel

@export var elemental : element
@export var elemental_desc : RichTextLabel
@export var stat_name : RichTextLabel
@export var stat_texture : TextureRect

func populate():
	stat_texture.texture = elemental.icon
	stat_name.text = elemental.name
	elemental_desc.text += "Elemental Status inflict:\n"
	for status in elemental.effects_to_add:
		elemental_desc.text += "	-" + status.status.name + " (" + str(status.chance * 100) + "%)\n"
