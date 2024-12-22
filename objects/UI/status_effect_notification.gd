extends Control

func status_effect_notif(status, add_remove):
	pass
	#$Icon.texture = status.icon
	#if add_remove:
		#$PlusOrMinus.text = "[center]+[/center]"
	#else:
		#$PlusOrMinus.text = "[center]-[/center]"
		#$AnimationPlayer.play("status_fade")


func _finish_anim(anim_name: StringName) -> void:
	queue_free()
