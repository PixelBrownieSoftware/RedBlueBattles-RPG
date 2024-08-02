extends CanvasLayer
signal fade_finish

func fade_bg(colour : Color, time : float = 0.5):
	if colour.a != 0:
		$ColorRect.visible = true
	print(colour)
	var tween_fade = create_tween()
	tween_fade.tween_property(
		$ColorRect,
		"color",
		colour,
		time
	).set_trans(Tween.TRANS_SINE)
	await tween_fade.finished
	if colour.a == 0:
		$ColorRect.visible = false
