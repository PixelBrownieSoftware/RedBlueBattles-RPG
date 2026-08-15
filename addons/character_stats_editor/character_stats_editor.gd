# res://addons/character_stats_editor/character_stats_editor.gd
@tool
extends Control

const CHAR_DIR := "res://data/characters"
const ELEMENT_DIR := "res://data/elements"
const SKILL_DIR := "res://data/skills"

const STAT_ICON_DIR := "res://sprites/GUI/stats/"
const ELEMENT_ICON_DIR := "res://sprites/GUI/elements/"

@onready var tree: Tree = %Tree
@onready var refresh_button: Button = %RefreshButton
@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

var current_path : String = ""
var current_res : battle_character_base = null
var elements : Array = []
var loaded_skills : Array = [] # Array of loaded rpg_skill resources

var stat_edits : Dictionary = {}
var increase_edits : Dictionary = {}
var potential_edits : Dictionary = {}
var affinity_display : ElementalAffinityDisplay # Custom control class with -1 to 2 sliders

var name_edit : LineEdit
var colour_edit : ColorPickerButton
var turns_edit : SpinBox
var health_edit : SpinBox
var stamina_edit : SpinBox

# Stamina-Up Array UI
var stamina_levels_vbox : VBoxContainer
var stamina_level_spins : Array[SpinBox] = []

# Skill Assignment Controls
var skill_search_edit : LineEdit
var skill_enable_checks : Dictionary = {}  # skill -> CheckBox
var skill_level_spins : Dictionary = {}     # skill -> SpinBox (level learned)
var skill_rows : Dictionary = {}            # skill -> HBoxContainer

var exp_score_edit : SpinBox
var exp_to_nl_edit : SpinBox
var exp_mult_edit : SpinBox
var health_min_edit : SpinBox
var health_max_edit : SpinBox

var dirty : bool = false
var suppress_signals : bool = false


func _ready() -> void:
	if not is_instance_valid(tree):
		return

	refresh_button.pressed.connect(_populate_tree)
	tree.item_selected.connect(_on_tree_item_selected)
	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	for child in form_root.get_children():
		child.queue_free()

	_load_elements()
	_load_skills()
	_build_form()
	_set_form_enabled(false)
	call_deferred("_populate_tree")


func _section_header(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(l)
	return panel


func _hsep() -> HSeparator:
	return HSeparator.new()


func _labeled_row(label_text: String, control: Control, icon_texture: Texture2D = null, label_width: int = 150) -> HBoxContainer:
	var row := HBoxContainer.new()
	
	if icon_texture:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(20, 20)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex_rect)
		
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	row.add_child(label)
	
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _make_int_spin(min_v: float, max_v: float, step: float = 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value_changed.connect(_on_field_changed)
	return s


func _make_float_spin(min_v: float, max_v: float, step: float = 0.01) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value_changed.connect(_on_field_changed)
	return s


func _load_gui_icon(dir_path: String, prefix: String, item_name: String) -> Texture2D:
	var clean_name := item_name.to_lower().strip_edges()
	var full_path := dir_path.path_join(prefix + clean_name + ".png")
	if ResourceLoader.exists(full_path):
		return load(full_path) as Texture2D
	return null


func _build_form() -> void:
	# ---- Identity ----
	form_root.add_child(_section_header("Identity"))
	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed(0))
	form_root.add_child(_labeled_row("Name", name_edit))

	colour_edit = ColorPickerButton.new()
	colour_edit.custom_minimum_size = Vector2(0, 26)
	colour_edit.color_changed.connect(func(_c): _on_field_changed(0))
	form_root.add_child(_labeled_row("Character Colour", colour_edit))

	turns_edit = _make_int_spin(1, 4, 1)
	form_root.add_child(_labeled_row("Turns", turns_edit))

	form_root.add_child(_hsep())

	# ---- Health / Stamina ----
	form_root.add_child(_section_header("Health / Stamina"))
	health_edit = _make_int_spin(1, 9999, 1)
	form_root.add_child(_labeled_row("Max Health", health_edit))

	stamina_edit = _make_int_spin(0, 999, 1)
	form_root.add_child(_labeled_row("Max Stamina", stamina_edit))

	# Dynamic Stamina-Up Levels Array Editor
	var stamina_array_row := VBoxContainer.new()
	stamina_array_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	stamina_levels_vbox = VBoxContainer.new()
	stamina_levels_vbox.add_theme_constant_override("separation", 4)
	stamina_array_row.add_child(stamina_levels_vbox)

	var add_stamina_btn := Button.new()
	add_stamina_btn.text = "+ Add Level"
	add_stamina_btn.custom_minimum_size = Vector2(100, 0)
	add_stamina_btn.pressed.connect(_on_add_stamina_level_pressed)
	stamina_array_row.add_child(add_stamina_btn)

	form_root.add_child(_labeled_row("Stamina-Up Levels", stamina_array_row))

	form_root.add_child(_hsep())

	# ---- Skill Assignment Configurator ----
	form_root.add_child(_section_header("Character Skills"))

	skill_search_edit = LineEdit.new()
	skill_search_edit.placeholder_text = "Search skills..."
	skill_search_edit.text_changed.connect(_on_skill_search_changed)
	form_root.add_child(_labeled_row("Filter Skills", skill_search_edit))

	var skill_scroll := ScrollContainer.new()
	skill_scroll.custom_minimum_size = Vector2(0, 200)
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var skill_vbox := VBoxContainer.new()
	skill_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_vbox.add_theme_constant_override("separation", 6)

	skill_rows.clear()
	for sk in loaded_skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var enable_cb := CheckBox.new()
		enable_cb.text = sk.name
		enable_cb.custom_minimum_size = Vector2(160, 0)
		enable_cb.toggled.connect(func(_t): _on_field_changed(0))
		skill_enable_checks[sk] = enable_cb
		row.add_child(enable_cb)

		# Skill Icon
		var icon_tex: Texture2D = sk.get("custom_icon") if sk.get("custom_icon") != null else sk.get("icon")
		if icon_tex:
			var tr := TextureRect.new()
			tr.texture = icon_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)


		skill_rows[sk] = row
		skill_vbox.add_child(row)

	skill_scroll.add_child(skill_vbox)
	form_root.add_child(skill_scroll)

	form_root.add_child(_hsep())

	# ---- Elemental Potential (Horizontal Icon Bar) ----
	form_root.add_child(_section_header("Elemental Potential"))
	var pot_container := HFlowContainer.new()
	pot_container.add_theme_constant_override("h_separation", 16)
	pot_container.add_theme_constant_override("v_separation", 8)
	form_root.add_child(pot_container)

	for el in elements:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		
		var icon: Texture2D = el.icon if el.icon else _load_gui_icon(ELEMENT_ICON_DIR, "elements_", el.name)
		if icon:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(24, 24)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.add_child(tr)
		else:
			var lbl := Label.new()
			lbl.text = el.name + ":"
			cell.add_child(lbl)

		var pot_spin := _make_float_spin(-6.0, 6.0, 0.1)
		pot_spin.custom_minimum_size = Vector2(70, 0)
		potential_edits[el] = pot_spin
		cell.add_child(pot_spin)

		pot_container.add_child(cell)

	form_root.add_child(_hsep())

	# ---- Elemental Affinities (Using ElementalAffinityDisplay control class) ----
	form_root.add_child(_section_header("Elemental Affinities (-1 to 2 Sliders)"))
	affinity_display = ElementalAffinityDisplay.new()
	affinity_display.upper_lower_limit = Vector2(-1.0, 2.0)
	affinity_display.default_value = 1.0 # Characters default to 1.0
	affinity_display.affinity_changed.connect(func(_el, _val): _on_field_changed(0))
	form_root.add_child(affinity_display)

	form_root.add_child(_hsep())

	# ---- Main Stats (With GUI Stat Icons) ----
	form_root.add_child(_section_header("Stats"))
	var stats_list := ["strength", "vitality", "dexterity", "magic_pow", "agility", "luck"]
	for stat_name in stats_list:
		var icon := _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
		var s := _make_int_spin(0, 99, 1)
		stat_edits[stat_name] = s
		form_root.add_child(_labeled_row(stat_name.capitalize(), s, icon))

	form_root.add_child(_hsep())

	# ---- Level-Up Growth ----
	form_root.add_child(_section_header("Level-Up Growth"))
	health_min_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Health / Level (min)", health_min_edit))
	health_max_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Health / Level (max)", health_max_edit))
	for stat_name in stats_list:
		var icon := _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
		var s := _make_float_spin(0.0, 5.0, 0.01)
		increase_edits[stat_name] = s
		form_root.add_child(_labeled_row(stat_name.capitalize() + " Rate", s, icon))

	form_root.add_child(_hsep())

	# ---- Experience ----
	form_root.add_child(_section_header("Experience"))
	exp_score_edit = _make_int_spin(0, 99999, 1)
	form_root.add_child(_labeled_row("EXP Awarded on Defeat", exp_score_edit))
	exp_to_nl_edit = _make_int_spin(0, 999999, 1)
	form_root.add_child(_labeled_row("EXP to Next Level", exp_to_nl_edit))
	exp_mult_edit = _make_float_spin(0.0, 10.0, 0.01)
	form_root.add_child(_labeled_row("EXP Requirement Multiplier", exp_mult_edit))


# Helper functions for Stamina-Up Levels UI
func _add_stamina_level_item(level_val: int = 1) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 99
	spin.step = 1
	spin.value = level_val
	spin.value_changed.connect(_on_field_changed)
	stamina_level_spins.append(spin)
	row.add_child(spin)

	var rem_btn := Button.new()
	rem_btn.text = "Remove"
	rem_btn.pressed.connect(func():
		stamina_level_spins.erase(spin)
		row.queue_free()
		_on_field_changed(0)
	)
	row.add_child(rem_btn)

	stamina_levels_vbox.add_child(row)


func _on_add_stamina_level_pressed() -> void:
	_add_stamina_level_item(1)
	_on_field_changed(0)


func _on_skill_search_changed(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for sk in skill_rows.keys():
		var row: HBoxContainer = skill_rows[sk]
		if filter == "" or sk.name.to_lower().contains(filter):
			row.visible = true
		else:
			row.visible = false


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	if is_instance_valid(affinity_display):
		affinity_display.is_editable = enabled
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child == affinity_display:
			continue
		if child is SpinBox or child is LineEdit:
			child.editable = enabled
		elif child is ColorPickerButton or child is Button or child is CheckBox:
			child.disabled = not enabled
		else:
			_set_container_editable(child, enabled)


func _load_elements() -> void:
	elements.clear()
	var paths := _find_resources_recursive(ELEMENT_DIR)
	for path in paths:
		var res = load(path)
		if res is element:
			elements.append(res)
	elements.sort_custom(func(a, b): return a.name < b.name)


func _load_skills() -> void:
	loaded_skills.clear()
	var paths := _find_resources_recursive(SKILL_DIR)
	for path in paths:
		var res = load(path)
		if res is rpg_skill:
			loaded_skills.append(res)
	loaded_skills.sort_custom(func(a, b): return a.name < b.name)


func _find_resources_recursive(path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.begins_with("."):
				file_name = dir.get_next()
				continue
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				results.append_array(_find_resources_recursive(full_path))
			elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
				results.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return results


func _populate_tree() -> void:
	if not tree:
		return
	tree.clear()
	var root := tree.create_item()

	if not DirAccess.dir_exists_absolute(CHAR_DIR):
		return

	var category_dir := DirAccess.open(CHAR_DIR)
	if not category_dir:
		return

	category_dir.list_dir_begin()
	var category_name := category_dir.get_next()
	while category_name != "":
		if not category_name.begins_with(".") and category_dir.current_is_dir():
			var category_path := CHAR_DIR.path_join(category_name)
			var category_item := tree.create_item(root)
			category_item.set_text(0, category_name)
			category_item.set_selectable(0, false)

			var char_paths := _find_resources_recursive(category_path)
			char_paths.sort()
			for cpath in char_paths:
				var res = load(cpath)
				if res is battle_character_base:
					var item := tree.create_item(category_item)
					item.set_text(0, res.name if res.name != "" else cpath.get_file())
					item.set_metadata(0, cpath)
		category_name = category_dir.get_next()
	category_dir.list_dir_end()

	if current_path != "":
		_select_item_by_path(current_path)


func _select_item_by_path(path: String) -> void:
	var root := tree.get_root()
	if not root:
		return
	for category_item in root.get_children():
		for item in category_item.get_children():
			if item.get_metadata(0) == path:
				item.select(0)
				return


func _on_tree_item_selected() -> void:
	var item := tree.get_selected()
	if not item:
		return
	var path = item.get_metadata(0)
	if path == null:
		return
	_load_character(path)


func _load_character(path: String) -> void:
	current_path = path
	current_res = load(path)
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	status_label.text = "Editing: " + current_res.name


func _populate_form() -> void:
	suppress_signals = true

	name_edit.text = current_res.name
	colour_edit.color = current_res.character_colour
	turns_edit.value = current_res.turns
	health_edit.value = current_res.health
	stamina_edit.value = current_res.stamina

	# Clear and rebuild Stamina Level SpinBoxes
	stamina_level_spins.clear()
	for child in stamina_levels_vbox.get_children():
		child.queue_free()

	if current_res.stamina_increase_levels != null:
		for lvl in current_res.stamina_increase_levels:
			_add_stamina_level_item(lvl)

	# Reset skill filter search box
	if skill_search_edit:
		skill_search_edit.text = ""
		_on_skill_search_changed("")

	# Populate Assigned Skills
	# Supports character_skills array containing skill entries or custom structs
	for sk in loaded_skills:
		var has_skill := false
		var learned_lvl := 1

		var char_skills = current_res.get("character_skills")
		if char_skills == null:
			char_skills = current_res.get("skills")

		if char_skills is Array:
			for entry in char_skills:
				if entry == null:
					continue
				# Check direct skill match or struct property match
				var entry_skill = entry if entry is rpg_skill else entry.get("skill")
				if entry_skill == sk or (entry_skill and entry_skill.name == sk.name):
					has_skill = true
					if not (entry is rpg_skill):
						learned_lvl = int(entry.get("level"))
					break

		skill_enable_checks[sk].button_pressed = has_skill

	for stat_name in stat_edits.keys():
		stat_edits[stat_name].value = current_res.stats.get(stat_name)

	health_min_edit.value = current_res.stat_increase.health_min
	health_max_edit.value = current_res.stat_increase.health_max
	for stat_name in increase_edits.keys():
		increase_edits[stat_name].value = current_res.stat_increase.get(stat_name)

	exp_score_edit.value = current_res.base_exp_score
	exp_to_nl_edit.value = current_res.base_exp_to_NL
	exp_mult_edit.value = current_res.exp_req_multipler

	for el in elements:
		var pot_value := 0.0
		for entry in current_res.elemental_potential:
			if entry.elemental == el:
				pot_value = entry.potential
				break
		if potential_edits.has(el):
			potential_edits[el].value = pot_value

	if is_instance_valid(affinity_display):
		affinity_display.display_affinities(current_res.elemental_affinities)

	suppress_signals = false


func _on_field_changed(_value) -> void:
	if suppress_signals or not current_res:
		return
	_apply_form_to_resource()
	dirty = true
	save_button.disabled = false
	revert_button.disabled = false
	status_label.text = "Unsaved changes to '" + current_res.name + "'"


func _apply_form_to_resource() -> void:
	current_res.name = name_edit.text
	current_res.character_colour = colour_edit.color
	current_res.turns = int(turns_edit.value)
	current_res.health = int(health_edit.value)
	current_res.stamina = int(stamina_edit.value)

	# Read Stamina-Up Levels from SpinBox Array
	var levels: Array[int] = []
	for spin in stamina_level_spins:
		if is_instance_valid(spin):
			levels.append(int(spin.value))
	current_res.stamina_increase_levels = levels

	# Build Character Skills array
	var new_character_skills: Array = []
	for sk in loaded_skills:
		if skill_enable_checks[sk].button_pressed:
			# Check if character resource expects struct or direct skill reference
			if ClassDB.class_exists("character_skill") or ResourceLoader.exists("res://scripts/resources/character_skill.gd"):
				var cs_res = load("res://scripts/resources/character_skill.gd")
				if cs_res:
					var cs = cs_res.new()
					cs.skill = sk
					cs.level = int(skill_level_spins[sk].value)
					new_character_skills.append(cs)
				else:
					new_character_skills.append(sk)
			else:
				new_character_skills.append(sk)

	if "character_skills" in current_res:
		current_res.set("character_skills", new_character_skills)
	elif "skills" in current_res:
		current_res.set("skills", new_character_skills)

	for stat_name in stat_edits.keys():
		current_res.stats.set(stat_name, int(stat_edits[stat_name].value))

	current_res.stat_increase.health_min = int(health_min_edit.value)
	current_res.stat_increase.health_max = int(health_max_edit.value)
	for stat_name in increase_edits.keys():
		current_res.stat_increase.set(stat_name, increase_edits[stat_name].value)

	current_res.base_exp_score = int(exp_score_edit.value)
	current_res.base_exp_to_NL = int(exp_to_nl_edit.value)
	current_res.exp_req_multipler = exp_mult_edit.value

	var new_potentials: Array[elemental_potential] = []
	for el in elements:
		if potential_edits.has(el):
			var val = potential_edits[el].value
			if not is_zero_approx(val):
				var entry := elemental_potential.new()
				entry.elemental = el
				entry.potential = val
				new_potentials.append(entry)
	current_res.elemental_potential = new_potentials

	var new_affinities: Array[elemental_affinity] = []
	if is_instance_valid(affinity_display):
		var current_aff_dict: Dictionary = affinity_display.get_affinities()
		for el_name in current_aff_dict.keys():
			var val: float = current_aff_dict[el_name]
			if not is_equal_approx(val, 1.0):
				var entry := elemental_affinity.new()
				entry.elementalName = el_name
				entry.affinity = val
				new_affinities.append(entry)
	current_res.elemental_affinities = new_affinities


func _on_save_pressed() -> void:
	if not current_res:
		return
	var err := ResourceSaver.save(current_res, current_path)
	if err == OK:
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "Saved '" + current_res.name + "' to disk."
	else:
		status_label.text = "Save failed (error %d)" % err


func _on_revert_pressed() -> void:
	if current_path == "":
		return
	current_res = ResourceLoader.load(current_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	_populate_form()
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	status_label.text = "Reverted '" + current_res.name + "'"
