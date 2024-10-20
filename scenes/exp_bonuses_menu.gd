extends Panel

func on_menu_show(results, total):
	$RichTextLabel.text += "[center]"
	$RichTextLabel.text += "You won!" if results["has_won"] else "You lost!"
	$RichTextLabel.text += "\n\n"
	for item in results:
		if item == "has_won":
			continue
		$RichTextLabel.text += item + ": " + str(results[item] * 100) +  "%\n"
	visible = true
	$Total.text += "[center]Total [img=45]sprites/GUI/gui_luc.png[/img] " + str(total) + "[/center]"
	$RichTextLabel.text += "[/center]"
	
func show_moves_learned(moves_learned):
	for skill : rpg_skill in moves_learned:
		$"Learned Skills".text += "Learned " + skill.name + "\n"

func show_rewards(rewards):
	for reward : String in rewards:
		$"Learned Skills".text += str(reward) + "\n"
