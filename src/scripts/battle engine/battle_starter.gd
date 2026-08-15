extends battle_state

@export 
var queue_state : battle_state
@export var actor_manager : battle_character_actor_manager

signal add_characters(group, actor_group)
# Called when the node enters the scene tree for the first time.
func start_state():
	CharacterFactory.connect("create_character_notification", actor_manager.add_character)
	CharacterFactory.connect("create_character_notification", queue_state.add_to_queue)
	#CharacterFactory.connect("delete_character_notification", actor_manager.delete_character)
	$"../../BattleCanvasLayer/Target Menu".hide()
	$"../../BattleCanvasLayer/Attack Menu".hide()
	for character in PartyMembers.get_children():
		if !GlobalVariables.enabled_party_members[character]:
			continue
		actor_manager.add_character(character)
	for character in EnemyMembers.get_children():
		actor_manager.add_character(character)
	#add_characters.emit(PartyMembers,get_node("../../BattleActors/Actors"))
	#add_characters.emit(EnemyMembers,get_node("../../BattleActors/Actors"))
	await FadeScene.fade_bg(Color(Color.BLACK,0),0.7)
	await get_tree().create_timer(0.8).timeout
	change_state.emit(queue_state)
