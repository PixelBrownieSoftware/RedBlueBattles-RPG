extends Panel

func on_menu_show(results, total):
	for item in results:
		$RichTextLabel.text += item + ": " + str(results[item] * 100) +  "%\n"
	visible = true
	$RichTextLabel.text += "Total: " + str(total)
	
func show_moves_learned(moves_learned):
	for skill : rpg_skill in moves_learned:
		$"Learned Skills".text += "Learned " + skill.name + "\n"

func show_rewards(rewards):
	for reward : String in rewards:
		$"Learned Skills".text += str(reward) + "\n"
