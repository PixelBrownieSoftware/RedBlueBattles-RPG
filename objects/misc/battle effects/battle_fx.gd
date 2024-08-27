extends Node2D

@export var animation_player : AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	animation_player.play("fx_animation")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
