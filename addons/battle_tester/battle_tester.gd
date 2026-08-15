# res://addons/battle_tester/battle_tester.gd
@tool
extends Control

const CHAR_DIR := "res://data/characters"
const SKILL_DIR := "res://data/skills"
const STATUS_DIR := "res://data/status_effects"

@onready var calculate_button: Button = %CalculateButton
@onready var refresh_button: Button = %RefreshButton
@onready var max_level_spin: SpinBox = %MaxLevelSpin
@onready var log_output: RichTextLabel = %LogOutput

# Left Column - Attacker
@onready var attacker_select: OptionButton = %AttackerSelect
@onready var attacker_level_slider: HSlider = %AttackerLevelSlider
@onready var attacker_lvl_label: Label = %AttackerLvlLabel
@onready var attacker_status_search: LineEdit = %AttackerStatusSearch
@onready var attacker_status_vbox: VBoxContainer = %AttackerStatusVBox
@onready var skill_search: LineEdit = %SkillSearch
@onready var skill_vbox: VBoxContainer = %SkillVBox

# Right Column - Defender
@onready var defender_select: OptionButton = %DefenderSelect
@onready var defender_level_slider: HSlider = %DefenderLevelSlider
@onready var defender_lvl_label: Label = %DefenderLvlLabel
@onready var defender_status_search: LineEdit = %DefenderStatusSearch
@onready var defender_status_vbox: VBoxContainer = %DefenderStatusVBox

# Loaded Data Arrays
var characters: Array = []       # battle_character_base
var skills: Array = []           # rpg_skill
var status_effects: Array = []   # status_effect

# Selection State
var selected_skill: rpg_skill = null
var skill_radio_buttons: Dictionary = {}

var attacker_status_checks: Dictionary = {}  # status_effect -> CheckBox
var attacker_status_rows: Dictionary = {}

var defender_status_checks: Dictionary = {}  # status_effect -> CheckBox
var defender_status_rows: Dictionary = {}

var skill_rows: Dictionary = {}


func _ready() -> void:
	if not is_instance_valid(log_output):
		return

	refresh_button.pressed.connect(_load_all_data)
	calculate_button.pressed.connect(_calculate_damage)
	max_level_spin.value_changed.connect(_on_max_level_changed)

	attacker_level_slider.value_changed.connect(func(v): attacker_lvl_label.text = "Lvl: %d" % int(v))
	defender_level_slider.value_changed.connect(func(v): defender_lvl_label.text = "Lvl: %d" % int(v))

	attacker_status_search.text_changed.connect(func(q): _filter_statuses(q, attacker_status_rows))
	defender_status_search.text_changed.connect(func(q): _filter_statuses(q, defender_status_rows))
	skill_search.text_changed.connect(_filter_skills)

	_on_max_level_changed(max_level_spin.value)
	_load_all_data()


func _on_max_level_changed(new_max: float) -> void:
	var m_val := maxf(10.0, new_max)
	attacker_level_slider.max_value = m_val
	defender_level_slider.max_value = m_val


func _load_all_data() -> void:
	_load_characters()
	_load_skills()
	_load_status_effects()
	_populate_ui()


func _load_characters() -> void:
	characters.clear()
	var paths := _find_resources_recursive(CHAR_DIR)
	for path in paths:
		var res = load(path)
		if res is battle_character_base:
			characters.append(res)
	characters.sort_custom(func(a, b): return a.name < b.name)


func _load_skills() -> void:
	skills.clear()
	var paths := _find_resources_recursive(SKILL_DIR)
	for path in paths:
		var res = load(path)
		if res is rpg_skill:
			skills.append(res)
	skills.sort_custom(func(a, b): return a.name < b.name)


func _load_status_effects() -> void:
	status_effects.clear()
	var paths := _find_resources_recursive(STATUS_DIR)
	for path in paths:
		var res = load(path)
		if res is status_effect:
			status_effects.append(res)
	status_effects.sort_custom(func(a, b): return a.name < b.name)


func _populate_ui() -> void:
	# Populate Dropdowns
	attacker_select.clear()
	defender_select.clear()

	for idx in range(characters.size()):
		var c = characters[idx]
		attacker_select.add_item(c.name, idx)
		defender_select.add_item(c.name, idx)

	if characters.size() > 1:
		defender_select.select(1)

	# Build Status Lists
	_build_status_list(attacker_status_vbox, attacker_status_checks, attacker_status_rows)
	_build_status_list(defender_status_vbox, defender_status_checks, defender_status_rows)

	# Build Skills List
	_build_skills_list()


func _build_status_list(vbox: VBoxContainer, check_dict: Dictionary, row_dict: Dictionary) -> void:
	for c in vbox.get_children():
		c.queue_free()

	check_dict.clear()
	row_dict.clear()

	for st in status_effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var cb := CheckBox.new()
		cb.text = st.name
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check_dict[st] = cb
		row.add_child(cb)

		if st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		row_dict[st] = row
		vbox.add_child(row)


func _build_skills_list() -> void:
	for c in skill_vbox.get_children():
		c.queue_free()

	skill_rows.clear()
	skill_radio_buttons.clear()

	var button_group := ButtonGroup.new()

	for sk in skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var radio := CheckBox.new()
		radio.button_group = button_group
		radio.text = sk.name
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radio.toggled.connect(func(pressed):
			if pressed:
				selected_skill = sk
		)
		skill_radio_buttons[sk] = radio
		row.add_child(radio)

		var icon_tex: Texture2D = sk.get("custom_icon") if sk.get("custom_icon") != null else sk.get("icon")
		if icon_tex:
			var tr := TextureRect.new()
			tr.texture = icon_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		var pwr_lbl := Label.new()
		pwr_lbl.text = "Pwr: " + str(sk.power)
		row.add_child(pwr_lbl)

		skill_rows[sk] = row
		skill_vbox.add_child(row)

	if skills.size() > 0:
		skill_radio_buttons[skills[0]].button_pressed = true
		selected_skill = skills[0]


func _filter_statuses(query: String, row_dict: Dictionary) -> void:
	var filter := query.strip_edges().to_lower()
	for st in row_dict.keys():
		var row: HBoxContainer = row_dict[st]
		row.visible = (filter == "" or st.name.to_lower().contains(filter))


func _filter_skills(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for sk in skill_rows.keys():
		var row: HBoxContainer = skill_rows[sk]
		row.visible = (filter == "" or sk.name.to_lower().contains(filter))


# ---- Combat Calculation Engine ----
func _calculate_damage() -> void:
	if attacker_select.selected < 0 or defender_select.selected < 0:
		log_output.text = "[color=red]Error: Please select both an Attacker and a Defender.[/color]"
		return

	if not selected_skill:
		log_output.text = "[color=red]Error: Please select an attacking skill.[/color]"
		return

	var attacker_base: battle_character_base = characters[attacker_select.selected]
	var defender_base: battle_character_base = characters[defender_select.selected]

	var attacker_lvl := int(attacker_level_slider.value)
	var defender_lvl := int(defender_level_slider.value)

	# 1. Instantiate runtime battle_character_data nodes
	var attacker_node := battle_character_data.new()
	attacker_node.name = "Attacker_" + attacker_base.name
	attacker_node.new_data(attacker_base, attacker_lvl)

	var defender_node := battle_character_data.new()
	defender_node.name = "Defender_" + defender_base.name
	defender_node.new_data(defender_base, defender_lvl)

	# 2. Attach selected status effects to character data nodes
	var atk_applied_effects: Array[status_effect_chance] = []
	for st in status_effects:
		if attacker_status_checks[st].button_pressed:
			var sec := status_effect_chance.new()
			sec.status = st
			sec.chance = 1.0
			atk_applied_effects.append(sec)
	attacker_node.apply_status_effects(atk_applied_effects)

	var def_applied_effects: Array[status_effect_chance] = []
	for st in status_effects:
		if defender_status_checks[st].button_pressed:
			var sec := status_effect_chance.new()
			sec.status = st
			sec.chance = 1.0
			def_applied_effects.append(sec)
	defender_node.apply_status_effects(def_applied_effects)

	# 3. Calculate Potential Modifiers
	var pot_mods: Dictionary = attacker_node.get_element_potential_modifiers(selected_skill)

	# 4. Accuracy / Hit Chance Calculation & Color Interpolation
	var hit_chance: float = attacker_node.calculate_chance(attacker_node.dexterity_net, defender_node.agility_net, 0.95)
	var hit_percentage_str: String = "%.1f%%" % (hit_chance * 100.0)
	var hit_color: Color = Color.RED.lerp(Color.GREEN, hit_chance)
	var hit_hex_color: String = hit_color.to_html(false)

	# 5. Run skill.process_damage()
	var attack_result: int = 0
	if selected_skill.has_method("process_damage"):
		attack_result = selected_skill.damage_formula(attacker_node, defender_node)

	var per_hit_dmg: int = attack_result
	var per_hit_dmg_luc: int = int(float(per_hit_dmg) * GlobalVariables.lucky_damage_bonus)

	# 6. Multi-hit roll checks
	var hit_min: int = selected_skill.repeat_min
	var hit_max: int = selected_skill.repeat_max
	var total_min_dmg: int = per_hit_dmg * hit_min
	var total_max_dmg: int = per_hit_dmg * hit_max
	var total_min_dmg_luc: int = per_hit_dmg_luc * hit_min
	var total_max_dmg_luc: int = per_hit_dmg_luc * hit_max

	# 7. Build Combat Readout Log
	var el_name := selected_skill.skill_element.name if selected_skill.skill_element else "None"
	var net_affinity := defender_node.get_elemental_affinity(selected_skill.skill_element) if selected_skill.skill_element else 1.0

	var log_txt := "[b]=== BATTLE SIMULATION LOG ===[/b]\n"
	log_txt += "[color=cyan]Attacker:[/color] %s (Lvl %d) | HP: %d/%d\n" % [attacker_base.name, attacker_lvl, attacker_node.health, attacker_node.max_health]
	log_txt += "[color=orange]Defender:[/color] %s (Lvl %d) | HP: %d/%d\n" % [defender_base.name, defender_lvl, defender_node.health, defender_node.max_health]
	log_txt += "[color=yellow]Skill Used:[/color] %s (Power: %d, Element: %s, Hits: %d-%d)\n\n" % [selected_skill.name, selected_skill.power, el_name, hit_min, hit_max]

	log_txt += "[b]Attacker Net Stats (Base + Status Mods):[/b]\n"
	log_txt += "• Str: %d | Vit: %d | Mag: %d | Dex: %d | Agi: %d | Luck: %d\n" % [attacker_node.strength_net, attacker_node.vitality_net, attacker_node.magic_pow_net, attacker_node.dexterity_net, attacker_node.agility_net, attacker_node.luck_net]
	log_txt += "• Potential Damage Multiplier: x%.2f\n\n" % pot_mods["damage_multipler"]

	log_txt += "[b]Defender Net Stats & Resistance:[/b]\n"
	log_txt += "• Str: %d | Vit: %d | Mag: %d | Dex: %d | Agi: %d | Luck: %d\n" % [defender_node.strength_net, defender_node.vitality_net, defender_node.magic_pow_net, defender_node.dexterity_net, defender_node.agility_net, defender_node.luck_net]
	log_txt += "• Net %s Affinity: [color=green]x%.2f[/color]\n\n" % [el_name, net_affinity]

	log_txt += "-----------------------------------------\n"
	log_txt += "[b]Hit Accuracy Chance:[/b] [color=#%s][b]%s[/b][/color]\n" % [hit_hex_color, hit_percentage_str]
	if hit_min == hit_max:
		log_txt += "[font_size=18][b]TOTAL DAMAGE DEALT: [color=lime]%d HP (%d LUCKY)[/color][/b][/font_size]" % [total_min_dmg, total_min_dmg_luc]
	else:
		log_txt += "[font_size=18][b]TOTAL DAMAGE RANGE (%d-%d Hits): [color=lime]%d - %d HP (%d - %d LUCKY)[/color][/b][/font_size]" % [hit_min, hit_max, total_min_dmg, total_max_dmg, total_min_dmg_luc, total_max_dmg_luc]

	log_output.text = log_txt

	# Cleanup temporary node instances
	attacker_node.free()
	defender_node.free()


func _find_resources_recursive(path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				var full_path := path.path_join(file_name)
				if dir.current_is_dir():
					results.append_array(_find_resources_recursive(full_path))
				elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
					results.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return results
