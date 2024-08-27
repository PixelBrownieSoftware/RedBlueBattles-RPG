extends Node2D
class_name  battle_character_actor

@export var hurt_sound : AudioStream
@export var defeat_sound : AudioStream
@export var character_data : battle_character_data
var character_anim : AnimationPlayer
var character_sprite : Sprite2D

signal anim_finish_signal()
var anim_finished_flag : bool = true

func play_animation(anim : String):
	if !character_anim.has_animation(anim):
		anim_finish_signal.emit()
		return false
	anim_finished_flag =false
	character_anim.play(anim)
	
func play_idle():
	play_animation_loop("idle")
	
func play_idle_active():
	play_animation_loop("idle_active")
	
func play_animation_loop(anim : String):
	character_anim.play(anim)
	
func character_anim_finished(anim):
	anim_finish_signal.emit()
	anim_finished_flag = true

func play_hurt_sound():
	$combatant_sfx.stream = hurt_sound
	$combatant_sfx.play()
	
func miss_anim():
	pass
	
func defeat_anim():
	await get_tree().create_timer(0.2).timeout
	$combatant_sfx_defeat.stream = defeat_sound
	$combatant_sfx_defeat.play()
	fade_character_colour(Color(Color.BLACK, 0))

func set_colour(colour: Color):
	character_sprite.modulate = colour

func fade_character_colour(colour: Color):
	var tween_fade = create_tween()
	await tween_fade.tween_property(
		character_sprite,
		"modulate",
		colour,
		0.5
	).set_trans(Tween.TransitionType.TRANS_SINE)
	anim_finish_signal.emit()

func assign_data(data : battle_character_data):
	character_data = data
	character_data.play_damage.connect(play_hurt_sound)
	character_data.defeat_event.connect(defeat_anim)
	var locate_anim = load("res://objects/character sprites/" + data.assigned_data.animation_player_loc + ".tscn")
	if locate_anim != null:
		var sprite = locate_anim.instantiate()
		add_child(sprite)
		character_sprite = sprite.get_child(0)
		if !GlobalVariables.is_player_team(data):
			character_sprite.flip_h = true
		character_anim = sprite.get_child(1)
		print(character_anim.animation_finished.get_connections())
		character_anim.animation_finished.connect(character_anim_finished)
		print(character_anim.animation_finished.get_connections())
