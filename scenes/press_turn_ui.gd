extends CanvasLayer

func _ready():
	disable_all()

func turn_icon_change(ind, mode):
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
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
