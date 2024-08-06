extends Panel

func on_menu_show(results, total):
	for item in results:
		$RichTextLabel.text += item + ": " + str(results[item] * 100) +  "%\n"
		visible = true
	$RichTextLabel.text += "Total: " + str(total)
	
