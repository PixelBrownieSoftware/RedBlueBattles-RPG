extends Panel

@export var status : status_effect
@export var elemental_desc : RichTextLabel
@export var stat_name : RichTextLabel
@export var stat_texture : TextureRect

func colour_text(stat, txt):
	var cost_colour = Color.GREEN if 0 < stat else Color.RED
	elemental_desc.text += "	" + txt + " ([" + "color=" + cost_colour.to_html() + "]" + str(stat) + "[/color])" + "\n"

func populate():
	stat_texture.texture = status.icon
	stat_name.text = status.name
	elemental_desc.text += "\n"
	if status is status_damage:
		if status.damage != 0:
			if status.damage < 0:
				elemental_desc.text += "	[color=green]+ " + str(status.damage)+ " health[/color]\n"
			else:
				elemental_desc.text += "	[color=red]-" +str(status.damage) + " health[/color]\n"
			elemental_desc.text += "\n"
			
	if status is status_stamina:
		if status.damage != 0:
			if status.damage > 0:
				elemental_desc.text += "	[color=green]+ " + str(status.damage)+ " stamina[/color]\n"
			else:
				elemental_desc.text +=  "	[color=red]" +str(status.damage) + " stamina[/color]\n"
			elemental_desc.text += "\n" 
	if status.elemental_affinity_change.size() > 0:
		for ele_aff : elemental_affinity in status.elemental_affinity_change:
			var is_negative : String = "[color=red] decreases [/color]" if ele_aff.affinity > 0 else "[color=green] increases [/color]" 
			var affinity = abs(ele_aff.affinity)
			if affinity > 0 && affinity <= 0.5:
				elemental_desc.text += "	Slightly" + is_negative + GlobalVariables.get_element(ele_aff.elementalName).get_coloured_name() + " resistance.\n"
			else: if affinity > 0.5:
				elemental_desc.text += "	Sharply" + is_negative + GlobalVariables.get_element(ele_aff.elementalName).get_coloured_name() + " resistance.\n"
		elemental_desc.text += "\n"
	if status.stat_changes.strength != 0:
		colour_text(status.stat_changes.strength, GlobalVariables.stat_colour(stats_name.STATS.STRENGTH) + ": ")
	if status.stat_changes.vitality != 0:
		colour_text(status.stat_changes.vitality, GlobalVariables.stat_colour(stats_name.STATS.VITALITY) +": ")
	if status.stat_changes.dexterity!= 0:
		colour_text(status.stat_changes.dexterity, GlobalVariables.stat_colour(stats_name.STATS.DEXTERITY) +": ")
	if status.stat_changes.agility!= 0:
		colour_text(status.stat_changes.agility, GlobalVariables.stat_colour(stats_name.STATS.AGILITY) +": ")
	if status.stat_changes.magic_pow != 0:
		colour_text(status.stat_changes.magic_pow, GlobalVariables.stat_colour(stats_name.STATS.MAGIC) +": ")
	if status.stat_changes.luck != 0:
		colour_text(status.stat_changes.luck, GlobalVariables.stat_colour(stats_name.STATS.LUCK) +": ")
	
	elemental_desc.text += "\n"
