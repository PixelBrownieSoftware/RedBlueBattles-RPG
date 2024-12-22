extends Node2D
class_name  battle_character_actor

@export var hurt_sound : AudioStream
@export var defeat_sound : AudioStream
@export var character_data : battle_character_data
@export var line_colour : Color
@onready var selector_arrow : Sprite2D = $SelectArrow
@onready var selector_arrow_anim : AnimationPlayer = selector_arrow.get_child(0)
var character_anim : AnimationPlayer
var character_sprite : Sprite2D
var is_player_team : bool

var min_select_thickness = 1.2
var max_select_thickness = 2.3
var select_time = 0.3

signal anim_finish_signal()
signal defeat_anim_finish(character)
signal select_character(character)
signal hover_character(character)
signal out_hover_character()
var anim_finished_flag : bool = true
var is_targetable = false
var target_tween

var character_hovered = false

func _ready() -> void:
	set_line_colour(line_colour)
	set_line_thickness(2)
	var circle : CircleShape2D = CircleShape2D.new()
	circle.radius= character_data.assigned_data.click_circle_radius
	$Area2D/CollisionShape2D.shape = circle
	selector_arrow.visible = false

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
	var is_permadeath = character_data.is_permadeath
	await get_tree().create_timer(0.2).timeout
	$combatant_sfx_defeat.stream = defeat_sound
	$combatant_sfx_defeat.play()
	await fade_character_colour(Color(Color.BLACK, 0))
	if is_permadeath:
		defeat_anim_finish.emit()
		queue_free()

func set_colour(colour: Color):
	set_character_colour(colour)

func fade_character_colour(colour: Color):
	var tween_fade = create_tween()
	await tween_fade.tween_method(set_character_colour,
	 Color.WHITE, colour,select_time).set_trans(Tween.TRANS_SINE)
	anim_finish_signal.emit()

func assign_data(data : battle_character_data):
	character_data = data
	is_player_team = GlobalVariables.is_player_team(data)
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

func calculate_outline_colour() -> Color:
	var current_health : float = character_data.health
	var max_health : float = character_data.max_health
	var colour_health : float = (current_health/max_health)
	var colour = Color.GREEN
	if colour_health < 0.75 && colour_health > 0.5:
		colour = Color.GREEN_YELLOW
	else:
		if colour_health < 0.5 && colour_health > 0.35:
			colour = Color.YELLOW
		else:
			if colour_health < 0.35 && colour_health > 0.2:
				colour = Color.ORANGE
			else:
				if colour_health < 0.2:
					colour = Color.RED
	return colour

func hover_emit():
	hover_character.emit(character_data)
	selector_arrow_anim.play("selected")
	#set_line_colour(calculate_outline_colour())
	#set_line_thickness(max_select_thickness)
	
func exit_emit():
	out_hover_character.emit()
	selector_arrow_anim.play("not_selected")
	#set_line_colour(calculate_outline_colour())
	#set_line_thickness(min_select_thickness)

func _on_mouse_hover() -> void:
	print("OK!")
	character_hovered = true
	if is_targetable:
		hover_emit()
		#if target_tween != null:
			#target_tween = create_tween()
			#target_tween.parallel().tween_method(set_line_colour, Color.AQUA, Color.RED,select_time).set_trans(Tween.TRANS_SINE)
			#target_tween.parallel().tween_method(set_line_thickness, min_select_thickness, max_select_thickness, select_time).set_trans(Tween.TRANS_SINE)


func _on_exit_mouse() -> void:
	character_hovered = false
	if is_targetable:
		exit_emit()
		#target_tween = null
		#target_tween = create_tween()
		#target_tween.parallel().tween_method(set_line_colour, Color.RED,Color.AQUA, select_time).set_trans(Tween.TRANS_SINE)
		#target_tween.parallel().tween_method(set_line_thickness, max_select_thickness, min_select_thickness,select_time).set_trans(Tween.TRANS_SINE)

func set_line_colour(colour):
	character_sprite.material.set("shader_parameter/line_colour",colour)
func set_character_colour(colour):
	character_sprite.material.set("shader_parameter/character_colour",colour)
func set_line_thickness(thickness):
	character_sprite.material.set("shader_parameter/line_thickness", thickness)
	
func toggle_highlight(on):
	is_targetable = on
	if on:
		if GlobalVariables.is_player_team(character_data):
			selector_arrow.flip_h = true
			selector_arrow.position = Vector2(30,-29)
		else:
			selector_arrow.flip_h = false
			selector_arrow.position = Vector2(-30,-29)
		selector_arrow.visible = true
		if character_hovered:
			hover_emit()
		else:
			exit_emit()
		#else:
	else:
		selector_arrow.visible = false
		#set_line_colour(Color(0,0,0,0))
		#set_line_thickness(0)

func _on_clicked(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if !is_targetable:
		return
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == 1:
				#selector_arrow.visible = false
				#set_line_colour(Color(0,0,0,0))
				#set_line_thickness(0)
				select_character.emit(character_data)
