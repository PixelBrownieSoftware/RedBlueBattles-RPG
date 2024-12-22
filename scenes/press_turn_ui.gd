extends CanvasLayer

func _ready():
	disable_all()

func turn_icon_change(ind, mode):
	if $"../../Variables".is_player_turn:
		$PressTurnContainer.get_child(ind).set_player_colour()
	else:
		$PressTurnContainer.get_child(ind).set_enemy_colour()
	match mode:
		"press":
			$PressTurnContainer.get_child(ind).glowing()
		"disappear":
			$PressTurnContainer.get_child(ind).disappear()
		"appear":
			$PressTurnContainer.get_child(ind).appear()

func disable_all():
	for press in $PressTurnContainer.get_children():
		press.visible = false
