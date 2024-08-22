extends Node
class_name battle_character_actor_manager
var base_character_actor = preload("res://objects/battle_combatant.tscn")
var base_character_ui = preload("res://objects/UI/hpgui.tscn")
var hurt_sound_player = preload("res://sound/damage_player.wav")
var hurt_sound_enemy = preload("res://sound/damage_enemy.wav")
var defeat_sound_player = preload("res://sound/player_defeat.wav")
var defeat_sound_enemy = preload("res://sound/enemy_defeat.wav")
@onready var battle_globals :battle_variables = $"../../Variables"
@export var position_nodes : Node

func add_characters(group, actor_group):
	if actor_group != self:
		return
	for chara in group.get_children():
		if group == PartyMembers:
			if !GlobalVariables.enabled_party_members[chara]:
				continue
		var actor = base_character_actor.instantiate()
		actor.position = position_nodes.get_child(chara.get_index()).position
		actor.assign_data(chara)
		actor.hurt_sound = hurt_sound_enemy
		actor.defeat_sound = defeat_sound_enemy
		add_child(actor)
		if group == PartyMembers:
			var chara_ui = base_character_ui.instantiate()
			chara_ui.character_data = chara
			chara.assign_signal(chara_ui.damage)
			chara.assign_start_turn_signal(chara_ui.enable_ui)
			chara.assign_end_turn_signal(chara_ui.disable_ui)
			$"../../UIAlign".add_child(chara_ui)
			actor.hurt_sound = hurt_sound_player
			actor.defeat_sound = defeat_sound_player
		actor.set_colour(Color(Color.BLACK, 0))
		actor.fade_character_colour(Color.WHITE)
