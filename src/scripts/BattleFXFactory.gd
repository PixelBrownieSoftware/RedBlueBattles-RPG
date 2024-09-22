extends Node
class_name battle_fx_factory
var hit_prefab = preload("res://objects/misc/hit_fx.tscn")
var status_info_prefab = preload("res://objects/UI/status_effect_notification.tscn")
var objects = {}
signal battle_fx_anim_done()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func spawn_damage_obj(user : battle_character_data, target : battle_character_data, number : int, pt : PRESS_TURN.PT):
	var actor = $"../Variables".get_actor(target)
	var hit = hit_prefab.instantiate()
	add_child(hit)
	hit.position = actor.position
	var is_player = GlobalVariables.is_player_team(target)
	hit.set_values(number, is_player, target.assigned_data.character_colour, pt)

func spawn_status_add_effect_info(status):
	var actor : battle_character_actor = $"../Variables".get_actor($"../Variables".target_character)
	var status_info = status_info_prefab.instantiate()
	status_info.position = actor.position
	status_info.status_effect_notif(status, true)
	
func spawn_status_remove_effect_info(status):
	var actor : battle_character_actor = $"../Variables".get_actor($"../Variables".target_character)
	var status_info = status_info_prefab.instantiate()
	#status_info.position = actor.position
	#add_child(status_info)
	status_info.status_effect_notif(status, false)

func spawn_attack_effect(object : String, target : battle_character_data):
	var actor : battle_character_actor = $"../Variables".get_actor(target)
	#cache the object prefab if it dosen't exist already
	if !objects.find_key(object):
		var key_object = load("res://objects/misc/battle effects/" + object + ".tscn")
		objects[object] = key_object
	var projectile = objects[object].instantiate()
	add_child(projectile)
	projectile.position = actor.position
	await projectile.animation_player.animation_finished
	battle_fx_anim_done.emit()
