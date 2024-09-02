extends Control
@export var status_FX : status_effect

func set_icon(status: status_effect):
	$Icon.texture = status.icon
	
func update_status(status: status_effect):
	if status.turn_duration < 2:
		$AnimationPlayer.play("status_fading")
	$Turns.text = str(status.turn_duration)
	if status.turn_duration == 0:
		$AnimationPlayer.play("status_fade")

func _on_animation_finished(anim_name: StringName) -> void:
	queue_free()
