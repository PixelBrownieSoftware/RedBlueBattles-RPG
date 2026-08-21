# res://addons/character_stats_editor/character_stats_editor.gd
@tool
extends Control

const CHAR_DIR := "res://data/characters"
const ELEMENT_DIR := "res://data/elements"
const SKILL_DIR := "res://data/skills"
const BEHAVIOUR_DIR := "res://data/behaviours"

const STAT_ICON_DIR := "res://sprites/GUI/stats/"
const ELEMENT_ICON_DIR := "res://sprites/GUI/elements/"

@onready var tree: Tree = %Tree
@onready var refresh_button: Button = %RefreshButton
@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

# File Management UI Controls
var new_char_button: Button
var delete_char_button: Button
var new_char_dialog: ConfirmationDialog
var new_char_name_input: LineEdit
var folder_select_option: OptionButton
var delete_confirm_dialog: ConfirmationDialog

var current_path : String = ""
var current_res : battle_character_base = null
var elements : Array = []
var loaded_skills : Array = []
var loaded_behaviours : Array[battle_chara_behaviour] = []

var stat_edits : Dictionary = {}
var increase_edits : Dictionary = {}
var potential_edits : Dictionary = {}
var affinity_display : ElementalAffinityDisplay

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
var skill_enable_checks : Dictionary = {}
var skill_rows : Dictionary = {}

# Behaviour Assignment Controls
var override_behaviour_check : CheckBox
var behaviour_vbox : VBoxContainer

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

	_setup_file_management_ui()

	refresh_button.pressed.connect(_populate_tree)
	tree.item_selected.connect(_on_tree_item_selected)
	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	for child in form_root.get_children():
		child.queue_free()

	_load_elements()
	_load_skills()
	_load_behaviours()
	_build_form()
	_set_form_enabled(false)
	call_deferred("_populate_tree")


func _setup_file_management_ui() -> void:
	var left_vbox: VBoxContainer = tree.get_parent()

	# Create button bar above the Tree view
	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 6)

	new_char_button = Button.new()
	new_char_button.text = "+ New Character"
	new_char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_char_button.pressed.connect(_on_new_character_pressed)
	action_hbox.add_child(new_char_button)

	delete_char_button = Button.new()
	delete_char_button.text = "Delete"
	delete_char_button.disabled = true
	delete_char_button.pressed.connect(_on_delete_character_pressed)
	action_hbox.add_child(delete_char_button)

	# Insert above the tree view
	var refresh_idx := refresh_button.get_index()
	left_vbox.add_child(action_hbox)
	left_vbox.move_child(action_hbox, refresh_idx + 1)

	# Setup "New Character" Confirmation Dialog
	new_char_dialog = ConfirmationDialog.new()
	new_char_dialog.title = "Create New Character"
	new_char_dialog.size = Vector2i(360, 160)

	var dialog_vbox := VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = "Character File Name:"
	dialog_vbox.add_child(name_lbl)

	new_char_name_input = LineEdit.new()
	new_char_name_input.placeholder_text = "new_character"
	dialog_vbox.add_child(new_char_name_input)

	var folder_lbl := Label.new()
	folder_lbl.text = "Target Category Folder:"
	dialog_vbox.add_child(folder_lbl)

	folder_select_option = OptionButton.new()
	dialog_vbox.add_child(folder_select_option)

	new_char_dialog.add_child(dialog_vbox)
	new_char_dialog.confirmed.connect(_confirm_new_character)
	add_child(new_char_dialog)

	# Setup "Delete Character" Confirmation Dialog
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "Delete Character Resource?"
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete this character file permanently?"
	delete_confirm_dialog.confirmed.connect(_confirm_delete_character)
	add_child(delete_confirm_dialog)


func _scan_character_folders() -> Array[String]:
	var folders: Array[String] = []
	if not DirAccess.dir_exists_absolute(CHAR_DIR):
		DirAccess.make_dir_recursive_absolute(CHAR_DIR)

	var dir := DirAccess.open(CHAR_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not file_name.begins_with(".") and dir.current_is_dir():
				folders.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	folders.sort()
	return folders


func _on_new_character_pressed() -> void:
	folder_select_option.clear()
	var folders := _scan_character_folders()

	folder_select_option.add_item("📁 Root (/data/characters)", 0)
	folder_select_option.set_item_metadata(0, CHAR_DIR)

	for idx in range(folders.size()):
		var folder_name := folders[idx]
		var full_path := CHAR_DIR.path_join(folder_name)
		folder_select_option.add_item("📂 " + folder_name, idx + 1)
		folder_select_option.set_item_metadata(idx + 1, full_path)

	new_char_name_input.text = "new_character"
	new_char_dialog.popup_centered()
	new_char_name_input.select_all()
	new_char_name_input.grab_focus()


func _confirm_new_character() -> void:
	var char_name := new_char_name_input.text.strip_edges()
	if char_name == "":
		return

	if not char_name.ends_with(".tres") and not char_name.ends_with(".res"):
		char_name += ".tres"

	var folder_idx := folder_select_option.selected
	var parent_dir: String = folder_select_option.get_item_metadata(folder_idx) if folder_idx >= 0 else CHAR_DIR

	var file_path := parent_dir.path_join(char_name)
	if FileAccess.file_exists(file_path):
		status_label.text = "Error: File '%s' already exists!" % char_name
		return

	var new_res := battle_character_base.new()
	new_res.name = char_name.get_basename().capitalize()

	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		status_label.text = "Created character at: " + file_path
		_populate_tree()
		_load_character(file_path)
	else:
		status_label.text = "Failed to create file (error %d)" % err


func _on_delete_character_pressed() -> void:
	if current_path == "":
		return

	delete_confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?" % current_path.get_file()
	delete_confirm_dialog.popup_centered()


func _confirm_delete_character() -> void:
	if current_path == "":
		return

	var file_to_delete := current_path
	var err := DirAccess.remove_absolute(file_to_delete)
	if err == OK:
		status_label.text = "Deleted character: " + file_to_delete.get_file()
		current_path = ""
		current_res = null
		_set_form_enabled(false)
		delete_char_button.disabled = true
		_populate_tree()
	else:
		status_label.text = "Failed to delete file (error %d)" % err


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
	skill_scroll.custom_minimum_size = Vector2(0, 180)
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

	# ---- Character Behaviours (chara_behaviour) ----
	form_root.add_child(_section_header("Character Behaviours (chara_behaviour)"))

	override_behaviour_check = CheckBox.new()
	override_behaviour_check.text = "Override Default Behaviours (Ignore AI Defaults)"
	override_behaviour_check.toggled.connect(func(_t): _on_field_changed(0))
	form_root.add_child(override_behaviour_check)

	behaviour_vbox = VBoxContainer.new()
	behaviour_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(behaviour_vbox)

	var add_behaviour_btn := Button.new()
	add_behaviour_btn.text = "+ Assign Behaviour Slot"
	add_behaviour_btn.pressed.connect(func():
		_add_behaviour_slot(null)
		_on_field_changed(0)
	)
	form_root.add_child(add_behaviour_btn)

	form_root.add_child(_hsep())

	# ---- Elemental Potential ----
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

	# ---- Elemental Affinities ----
	form_root.add_child(_section_header("Elemental Affinities (-1 to 2 Sliders)"))
	affinity_display = ElementalAffinityDisplay.new()
	affinity_display.upper_lower_limit = Vector2(-1.0, 2.0)
	affinity_display.default_value = 1.0
	affinity_display.affinity_changed.connect(func(_el, _val): _on_field_changed(0))
	form_root.add_child(affinity_display)

	form_root.add_child(_hsep())

	# ---- Main Stats ----
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


func _add_behaviour_slot(selected_beh: battle_chara_behaviour = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var beh_select := OptionButton.new()
	beh_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beh_select.add_item("None (Empty Slot)", 0)

	var match_idx := 0
	for idx in range(loaded_behaviours.size()):
		var beh := loaded_behaviours[idx]
		var path_name := beh.resource_path.get_file().get_basename()
		var display_text := "🧠 " + path_name + " (Priority: " + str(beh.priority if "priority" in beh else 0) + ")"
		beh_select.add_item(display_text, idx + 1)
		beh_select.set_item_metadata(idx + 1, beh)

		if selected_beh and beh == selected_beh:
			match_idx = idx + 1

	if match_idx > 0:
		beh_select.select(match_idx)

	beh_select.item_selected.connect(func(_idx): _on_field_changed(0))
	row.add_child(beh_select)

	var del_btn := Button.new()
	del_btn.text = "Remove"
	del_btn.pressed.connect(func():
		row.queue_free()
		_on_field_changed(0)
	)
	row.add_child(del_btn)

	row.set_meta("beh_select", beh_select)
	behaviour_vbox.add_child(row)


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
	if is_instance_valid(delete_char_button):
		delete_char_button.disabled = not enabled
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


func _load_behaviours() -> void:
	loaded_behaviours.clear()
	if DirAccess.dir_exists_absolute(BEHAVIOUR_DIR):
		var paths := _find_resources_recursive(BEHAVIOUR_DIR)
		for path in paths:
			var res = load(path)
			if res is battle_chara_behaviour:
				loaded_behaviours.append(res)


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
	_load_behaviours()
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	delete_char_button.disabled = false
	status_label.text = "Editing: " + current_res.name


func _populate_form() -> void:
	suppress_signals = true

	name_edit.text = current_res.name
	colour_edit.color = current_res.character_colour
	turns_edit.value = current_res.turns
	health_edit.value = current_res.health
	stamina_edit.value = current_res.stamina

	stamina_level_spins.clear()
	for child in stamina_levels_vbox.get_children():
		child.queue_free()

	if current_res.stamina_increase_levels != null:
		for lvl in current_res.stamina_increase_levels:
			_add_stamina_level_item(lvl)

	if skill_search_edit:
		skill_search_edit.text = ""
		_on_skill_search_changed("")

	for sk in loaded_skills:
		var has_skill := false
		var char_skills = current_res.get("character_skills")
		if char_skills == null:
			char_skills = current_res.get("skills")

		if char_skills is Array:
			for entry in char_skills:
				if entry == null:
					continue
				var entry_skill = entry if entry is rpg_skill else entry.get("skill")
				if entry_skill == sk or (entry_skill and entry_skill.name == sk.name):
					has_skill = true
					break

		skill_enable_checks[sk].button_pressed = has_skill

	if "override_default_behaviours" in current_res:
		override_behaviour_check.button_pressed = current_res.override_default_behaviours
	else:
		override_behaviour_check.button_pressed = false

	for child in behaviour_vbox.get_children():
		child.queue_free()

	if current_res.chara_behaviour:
		for beh in current_res.chara_behaviour:
			if beh:
				_add_behaviour_slot(beh)

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

	var levels: Array[int] = []
	for spin in stamina_level_spins:
		if is_instance_valid(spin):
			levels.append(int(spin.value))
	current_res.stamina_increase_levels = levels

	var new_character_skills: Array = []
	for sk in loaded_skills:
		if skill_enable_checks[sk].button_pressed:
			new_character_skills.append(sk)

	if "character_skills" in current_res:
		current_res.set("character_skills", new_character_skills)
	elif "skills" in current_res:
		current_res.set("skills", new_character_skills)

	if "override_default_behaviours" in current_res:
		current_res.override_default_behaviours = override_behaviour_check.button_pressed

	var assigned_behaviours: Array[battle_chara_behaviour] = []
	for row in behaviour_vbox.get_children():
		var beh_select: OptionButton = row.get_meta("beh_select")
		if beh_select and beh_select.selected > 0:
			var selected_beh: battle_chara_behaviour = beh_select.get_item_metadata(beh_select.selected)
			if selected_beh:
				assigned_behaviours.append(selected_beh)
	current_res.chara_behaviour = assigned_behaviours

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
