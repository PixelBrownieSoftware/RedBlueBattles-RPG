extends Panel

@export var npc_behaviour_node: Node
@onready var output_label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	visible = false

func display_stuff():
	if not is_instance_valid(npc_behaviour_node) or not npc_behaviour_node.has_method("get_acceptable_behaviours"):
		if is_instance_valid(output_label):
			output_label.text = "[color=red]Error: NPC Behaviour node not assigned or invalid.[/color]"
		return

	var current_chara = npc_behaviour_node.battle_globals.current_character if "battle_globals" in npc_behaviour_node else null
	if not current_chara:
		return

	var acceptable_actions: Array[Dictionary] = npc_behaviour_node.get_acceptable_behaviours()
	
	var txt := "Round: " + str($"../../Variables".round_number) + "\n"
	txt += "[b]Active Enemy:[/b] [color=cyan]%s[/color] (Stamina: %d)\n" % [current_chara.name, current_chara.stamina]
	txt += "[b]Available Acceptable Actions (%d total):[/b]\n" % acceptable_actions.size()
	txt += "[hsep]\n"

	if acceptable_actions.is_empty():
		txt += "[color=yellow]No behaviours matched. Fallback: Guard[/color]"
	else:
		for idx in range(acceptable_actions.size()):
			var action = acceptable_actions[idx]
			var skill: rpg_skill = action["skill"]
			var targets: Array[battle_character_data] = action["targets"]
			
			var target_names := []
			for t in targets:
				target_names.append(t.name)

			txt += "[b]%d. Skill:[/b] [color=yellow]%s[/color] (Cost: %d)\n" % [idx + 1, skill.name, skill.get_final_cost(current_chara)]
			txt += "   • [b]Priority:[/b] %d  |  [b]Weight:[/b] %.1f%%\n" % [action["priority"], action["percentage"] * 100.0]
			txt += "   • [b]Valid Targets:[/b] [color=green]%s[/color]\n\n" % [", ".join(target_names)]

	if is_instance_valid(output_label):
		output_label.text = txt
	visible = true
