extends battle_state

@export 
var queue_state : battle_state

signal add_characters(group, actor_group)
# Called when the node enters the scene tree for the first time.
func start_state():
	$"../../BattleCanvasLayer/Target Menu".hide()
	$"../../BattleCanvasLayer/Attack Menu".hide()
	add_characters.emit(PartyMembers,get_node("../../BattleActors/PartyMemberActors"))
	add_characters.emit(EnemyMembers,get_node("../../BattleActors/EnemyMemberActors"))
	
	await FadeScene.fade_bg(Color(Color.BLACK,0),0.7)
	await get_tree().create_timer(0.8).timeout
	change_state.emit(queue_state)
