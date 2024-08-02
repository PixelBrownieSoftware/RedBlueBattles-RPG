extends Panel

func notificaiton_up(skill):
	$RichTextLabel.text = "[center]" + skill.name + "[/center]"
	$AnimationPlayer.play("notification_up")
