extends Control

@export var character_data : battle_character_data
var status_effect_icon_prefab = preload("res://objects/UI/status_effect_icon.tscn")
var old_health
signal update_status_effect(status)
@export var enemy_hp_colour : Color

func _process(delta):
	if character_data != null:
		var hp_clamp: int = 0
		hp_clamp = clampi(character_data.health ,0 ,character_data.max_health)
		var character_colour = character_data.assigned_data.character_colour
		var status_colour = Color.WHITE
		if hp_clamp == 0:
			status_colour = Color.DARK_RED
		if !GlobalVariables.is_player_team(character_data):
			character_colour = Color.WHITE
		$Offset/Name.text = "[color=" + character_colour.to_html() + "]" + character_data.name + "[/color]" 
		$Offset/Hp.text ="[color=" + status_colour.to_html() + "]" + "HP "+ str(hp_clamp) + "/" +str(character_data.max_health)+ "[/color]" 
		$Offset/HealthBar.max_value = character_data.max_health
		$Offset/HealthBar.min_value = 0
		$Offset/HealthBar.value = clampi(character_data.health, 0, character_data.max_health)
		if GlobalVariables.is_player_team(character_data):
			$Offset/HealthBar.get("theme_override_styles/fill").bg_color = character_data.assigned_data.character_colour
		else:
			$Offset/HealthBar.get("theme_override_styles/fill").bg_color = enemy_hp_colour
			
		$Offset/StaminaContainer.render_stamina(character_data.stamina, character_data.max_stamina)

func enable_ui():
	$AnimationPlayer.play("up")

func disable_ui():
	$AnimationPlayer.play("down")
	
func delete_ui():
	queue_free()	

func init_dmg_bar():
	old_health = character_data.health
	$Offset/DamageBar.value = old_health
	$Offset/DamageBar.max_value = character_data.max_health
	
func update_status(status : status_effect):
	update_status_effect.emit(status)

func add_status_effect(status : status_effect):
	var status_gui = status_effect_icon_prefab.instantiate()
	status_gui.set_icon(status)
	update_status_effect.connect(status_gui.update_status)
	update_status_effect.emit(status)
	$Offset/StatusEffects.add_child(status_gui)

func damage():
	$AnimationPlayer.play("damage")
	$Offset/DamageBar.value = old_health
	var current_char_health_cache : int = character_data.health
	var current_char_colour : Color = character_data.assigned_data.character_colour
	var is_player_team_cache : bool = GlobalVariables.is_player_team(character_data)
	for i in range(4):
		if is_player_team_cache:
			$Offset/DamageBar.get("theme_override_styles/fill").bg_color = Color.WHITE
		else:
			$Offset/DamageBar.get("theme_override_styles/fill").bg_color = Color.CORNFLOWER_BLUE
		
		await get_tree().create_timer(0.1).timeout
		if is_player_team_cache:
			$Offset/DamageBar.get("theme_override_styles/fill").bg_color = current_char_colour
		else:
			$Offset/DamageBar.get("theme_override_styles/fill").bg_color = enemy_hp_colour
		await get_tree().create_timer(0.1).timeout
	old_health = current_char_health_cache
	$Offset/DamageBar.value = old_health
