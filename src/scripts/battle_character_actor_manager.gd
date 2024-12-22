extends Node
class_name battle_character_actor_manager
var base_character_actor = preload("res://objects/battle_combatant.tscn")
var base_character_ui = preload("res://objects/UI/hpgui.tscn")
var hurt_sound_player = preload("res://sound/damage_player.wav")
var hurt_sound_enemy = preload("res://sound/damage_enemy.wav")
var defeat_sound_player = preload("res://sound/player_defeat.wav")
var defeat_sound_enemy = preload("res://sound/enemy_defeat.wav")
@onready var battle_globals :battle_variables = $"../../Variables"

@export var fx_factory : battle_fx_factory
@export var exp_watch : exp_watcher
var party_member_menu = preload("res://objects/UI/party_member_tab_battle.tscn")

func reposition_characters():
	for character in EnemyMembers.get_children():
		var actor : battle_character_actor = battle_globals.get_actor(character)
		var pos_node = $"../EnemyPositions".get_child(character.get_index())
		actor.position = pos_node.position
	for character in PartyMembers.get_children():
		var actor : battle_character_actor = battle_globals.get_actor(character)
		var pos_node = $"../PartyPositions".get_child(character.get_index())
		actor.position = pos_node.position

func add_character(chara):
	if battle_globals.get_actor(chara):
		return
	chara.increase_multiplier.connect(exp_watch.increase_multiplier)
	var actor : battle_character_actor = base_character_actor.instantiate()
	var position_groups = $"../PartyPositions" if GlobalVariables.is_player_team(chara) else $"../EnemyPositions"
	var pos_node = position_groups.get_child(chara.get_index())
	actor.position = pos_node.position
	actor.assign_data(chara)
	actor.hurt_sound = hurt_sound_enemy
	actor.defeat_sound = defeat_sound_enemy
	actor.character_anim.play("idle")
	actor.hover_character.connect($"../../BattleCanvasLayer/Target Menu/CharacterInfo".on_character_hover) 
	actor.out_hover_character.connect($"../../BattleCanvasLayer/Target Menu/CharacterInfo".on_character_exit)
	actor.select_character.connect($"../../BattleCanvasLayer/Target Menu".on_select_character)
	add_child(actor)
	chara.put_damage_numbers.connect(fx_factory.spawn_damage_obj)
	var chara_ui = base_character_ui.instantiate()
	chara_ui.character_data = chara
	chara_ui.init_dmg_bar()
	actor.connect("defeat_anim_finish", chara_ui.delete_ui)
	actor.connect("defeat_anim_finish", reposition_characters)
	chara.assign_signal(chara_ui.damage)
	chara.assign_add_status_signal(chara_ui.add_status_effect)
	chara.assign_add_status_signal(fx_factory.spawn_status_add_effect_info)
	chara.assign_remove_status_signal(fx_factory.spawn_status_remove_effect_info)
	chara.assign_update_status_signal(chara_ui.update_status)
	chara.assign_start_turn_signal(chara_ui.enable_ui)
	chara.assign_start_turn_signal(actor.play_idle_active)
	chara.assign_end_turn_signal(chara_ui.disable_ui)
	chara.assign_end_turn_signal(actor.play_idle)
	if GlobalVariables.is_player_team(chara):
		$"../../BattleCanvasLayer/UIAlignParty".add_child(chara_ui)
	else:
		$"../../BattleCanvasLayer/UIAlignEnemy".add_child(chara_ui)
	if GlobalVariables.is_player_team(chara):
		actor.hurt_sound = hurt_sound_player
		actor.defeat_sound = defeat_sound_player
	actor.set_colour(Color(Color.BLACK, 0))
	actor.fade_character_colour(Color.WHITE)

#func add_characters(group, actor_group):
	#if actor_group != self:
		#return
	#for chara in group.get_children():
		#if group == PartyMembers:
			#if !GlobalVariables.enabled_party_members[chara]:
				#continue
		#add_character(chara, false)
