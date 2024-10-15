extends HBoxContainer
class_name stat_display
@export var character : battle_character_data
@export var st_disp : stats_name.STATS

func on_character_load(character : battle_character_data) -> void:
	self.character = character

func _process(delta: float) -> void:
	if character != null:
		var stat_amount = 0
		var stat_amount_net = 0
		match st_disp:
			stats_name.STATS.STRENGTH:
				stat_amount = character.strength
				stat_amount_net = character.strength_net
			stats_name.STATS.VITALITY:
				stat_amount = character.vitality
				stat_amount_net = character.vitality_net
			stats_name.STATS.DEXTERITY:
				stat_amount = character.dexterity
				stat_amount_net = character.dexterity_net
			stats_name.STATS.MAGIC:
				stat_amount = character.magic_pow
				stat_amount_net = character.magic_pow_net
			stats_name.STATS.AGILITY:
				stat_amount = character.agility
				stat_amount_net = character.agility_net
			stats_name.STATS.LUCK:
				stat_amount = character.luck
				stat_amount_net = character.luck_net
		if stat_amount_net >= stat_amount:
			$StatBar.value = stat_amount_net
		else:
			$StatBar.value = stat_amount
		$Name.text = GlobalVariables.stat_colour(st_disp) + ": "
		$Stat.text =  str(stat_amount_net)
