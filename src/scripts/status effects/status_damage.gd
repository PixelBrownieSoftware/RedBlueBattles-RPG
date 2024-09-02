extends status_effect
class_name status_damage
@export var damage : int

func _on_after_action(chara : battle_character_data):
	super(chara)
	chara.damage(damage)
