extends Control

func _ready() -> void:
	if GlobalVariables.current_level.texture_BG != null:
		$BattleBg2.texture = GlobalVariables.current_level.texture_BG
		$BattleBg.texture = GlobalVariables.current_level.texture_BG
	
	if GlobalVariables.current_level.colour_BG != null:
		$ColorRect.color = GlobalVariables.current_level.colour_BG

func dim_bg():
	$AnimationPlayer.play("fade")
	

func light_bg():
	$AnimationPlayer.play_backwards("fade")
