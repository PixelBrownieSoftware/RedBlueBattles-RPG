extends status_effect
class_name status_stamina
@export var damage : int	#Can drain or increase stamina

func _on_round_start(chara : battle_character_data):
	super(chara)
	chara.change_stamina(damage)
