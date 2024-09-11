extends Panel

@export var group : button_group

func _ready() -> void:
	var unlock : Array[String]
	var battle_group = {
		"opp" : {},
		"unl" : unlock,
	}
	if group != null:
		for gr in group.battle_groups:
			for member in gr.opponents:
				if !battle_group["opp"].find_key(member.character):
					var move_arr : Array[String]
					battle_group["opp"][member.character.name] = {
						"min_lvl": 99999,
						"max_lvl": -99999,
						"moves_to_learn": move_arr
					}
				for move in member.skills:
					if battle_group["opp"][member.character.name]["moves_to_learn"].rfind(move.name) == -1:
						var txt = "[color=" + move.skill_element.colour.to_html() + "]" + move.name + "[/color]"
						battle_group["opp"][member.character.name]["moves_to_learn"].append(txt)
				if battle_group["opp"][member.character.name]["min_lvl"] > member.min_level:
					battle_group["opp"][member.character.name]["min_lvl"] =member.min_level
				if battle_group["opp"][member.character.name]["max_lvl"] < member.max_level:
					battle_group["opp"][member.character.name]["max_lvl"] =member.max_level
			for member in gr.rewards:
				if !GlobalVariables.check_flag(member.flag_req):
					var txt = member.display_reward()
					battle_group["unl"].append(txt)
					
		$RichTextLabel.text += "[u]" +group.text + "[/u]\n"
		for gr in battle_group["opp"].keys():
			var obj =  battle_group["opp"][gr]
			if obj["min_lvl"] == obj["max_lvl"]:
				$RichTextLabel.text += gr + " Lv." + str(obj["min_lvl"]) + '\n'
			else:
				$RichTextLabel.text += gr + " Lv." + str(obj["min_lvl"]) + " - "+ str(obj["max_lvl"])+ '\n'
			if obj["moves_to_learn"].size() > 0:
				$RichTextLabel.text += "	[b][u]Extra skills[/u][/b]:\n"
				for move in obj["moves_to_learn"]:
					$RichTextLabel.text += "	 - " + move + "\n"
				$RichTextLabel.text += '\n'
		if battle_group["unl"].size() > 0:
			$RichTextLabel.text += '\n[u]Unlockables[/u]\n'
			for gr in battle_group["unl"]:
				$RichTextLabel.text += gr + '\n'
