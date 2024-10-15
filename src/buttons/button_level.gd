extends Button
class_name button_level

@export var battle_level : battle_level_group
#TODO: Maybe put a flag requirement
signal load_level(level : battle_level_group)

func assign_data(level : battle_level_group):
	match level.type_battle:
		battle_level_group.battle_type.NORMAL:
			self_modulate = Color.WHITE
		battle_level_group.battle_type.EASY:
			self_modulate = Color.ROSY_BROWN
		battle_level_group.battle_type.MEDIUM:
			self_modulate = Color.SILVER
		battle_level_group.battle_type.HARD:
			self_modulate = Color.GOLD
		battle_level_group.battle_type.BOSS:
			self_modulate = Color.MEDIUM_PURPLE
		battle_level_group.battle_type.MINI_BOSS:
			self_modulate = Color.ORANGE
	battle_level = level
	text = battle_level.name

func _on_pressed():
	load_level.emit(battle_level)
