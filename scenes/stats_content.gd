extends HBoxContainer
@export var stamina_show : RichTextLabel

func update_stats(character : battle_character_data) -> void:
	$VBoxContainer/Health.text = "Health: " + str(character.max_health)
	var stamina_text = ""
	for i in range(character.max_stamina):
		stamina_text += "[img=18]sprites/GUI/stamina_gui.png[/img]"
	stamina_show.text = "Stamina: " + stamina_text

func on_character_load(character : battle_character_data):
	update_stats(character)
	var chara_sprite = load("res://objects/character sprites/" + character.assigned_data.animation_player_loc + ".tscn")
	var inst = chara_sprite.instantiate()
	var sprite : Sprite2D = inst.get_child(0)
	$CharacterSprite/Sprite2D.texture = sprite.texture
	$CharacterSprite/Sprite2D.hframes = sprite.hframes
	$CharacterSprite/Sprite2D.vframes = sprite.vframes
	$CharacterSprite/Sprite2D.frame = 0
