# res://addons/character_stats_editor/character_stats_editor.gd
@tool
extends Control

const CHAR_DIR := "res://data/characters"
const ELEMENT_DIR := "res://data/elements"
const SKILL_DIR := "res://data/skills"
const BEHAVIOUR_DIR := "res://data/behaviours"
const SPRITE_DIR := "res://objects/character sprites/"

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
var copy_char_button: Button
var rename_char_button: Button
var delete_char_button: Button

var new_char_dialog: ConfirmationDialog
var new_char_name_input: LineEdit
var folder_select_option: OptionButton

var copy_char_dialog: ConfirmationDialog
var copy_source_option: OptionButton
var copy_confirm_dialog: ConfirmationDialog

var rename_char_dialog: ConfirmationDialog
var rename_char_name_input: LineEdit
var move_folder_select_option: OptionButton

var delete_confirm_dialog: ConfirmationDialog

var current_path : String = ""
var current_res : battle_character_base = null
var elements : Array = []
var loaded_skills : Array = []
var loaded_behaviours : Array[battle_chara_behaviour] = []
var loaded_sprite_names : Array[Dictionary] = [] # Array of {"display_name": String, "sprite_name": String, "full_path": String}

var stat_edits : Dictionary = {}
var increase_edits : Dictionary = {}
var potential_edits : Dictionary = {}
var affinity_display : ElementalAffinityDisplay

var name_edit : LineEdit
var colour_edit : ColorPickerButton
var turns_edit : SpinBox
var health_edit : SpinBox
var stamina_edit : SpinBox
var sprite_select : OptionButton

# Stamina-Up Array UI
var stamina_levels_vbox : VBoxContainer
var stamina_level_spins : Array[SpinBox] = []

# Skill Assignment Tabbed Controls
var skill_search_edit : LineEdit
var skill_tab_container : TabContainer
var assigned_skills_vbox : VBoxContainer
var unassigned_skills_vbox : VBoxContainer
var skill_cards : Dictionary = {}           # rpg_skill -> Control (Card Container)
var skill_enable_checks : Dictionary = {}   # rpg_skill -> CheckBox

# Behaviour Assignment Controls (chara_behaviour_n using battle_ch_bh_perc)
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

	# Listen to Godot editor filesystem changes to auto-update behaviours and sprites
	if Engine.is_editor_hint():
		var ef := EditorInterface.get_resource_filesystem()
		if ef and not ef.filesystem_changed.is_connected(_on_filesystem_changed):
			ef.filesystem_changed.connect(_on_filesystem_changed)

	for child in form_root.get_children():
		child.queue_free()

	_load_elements()
	_load_skills()
	_load_behaviours()
	_load_sprites()
	_build_form()
	_set_form_enabled(false)
	call_deferred("_populate_tree")


func _on_filesystem_changed() -> void:
	_load_behaviours()
	_load_sprites()
	_refresh_behaviour_dropdown_options()
	_refresh_sprite_dropdown_options()


func _refresh_sprite_dropdown_options() -> void:
	if not is_instance_valid(sprite_select):
		return

	var current_selected_sprite := ""
	if sprite_select.selected > 0:
		current_selected_sprite = sprite_select.get_item_metadata(sprite_select.selected)

	sprite_select.clear()
	sprite_select.add_item("None (No Sprite)", 0)
	sprite_select.set_item_metadata(0, "")

	var match_idx := 0
	for idx in range(loaded_sprite_names.size()):
		var item := loaded_sprite_names[idx]
		var item_idx := idx + 1
		sprite_select.add_item("🎬 " + item.display_name, item_idx)
		sprite_select.set_item_metadata(item_idx, item.sprite_name)

		if current_selected_sprite != "" and item.sprite_name == current_selected_sprite:
			match_idx = item_idx

	sprite_select.select(match_idx)


func _refresh_behaviour_dropdown_options() -> void:
	if not is_instance_valid(behaviour_vbox):
		return

	for card in behaviour_vbox.get_children():
		var beh_select: OptionButton = card.get_meta("beh_select") if card.has_meta("beh_select") else null
		if not is_instance_valid(beh_select):
			continue

		var current_selected_beh = null
		if beh_select.selected > 0:
			current_selected_beh = beh_select.get_item_metadata(beh_select.selected)

		beh_select.clear()
		beh_select.add_item("None (Empty Slot)", 0)

		var new_match_idx := 0
		for idx in range(loaded_behaviours.size()):
			var beh := loaded_behaviours[idx]
			var path_name := beh.resource_path.get_file().get_basename()
			var display_text := "🧠 " + path_name
			beh_select.add_item(display_text, idx + 1)
			beh_select.set_item_metadata(idx + 1, beh)

			if current_selected_beh and beh == current_selected_beh:
				new_match_idx = idx + 1

		beh_select.select(new_match_idx)


func _setup_file_management_ui() -> void:
	var left_vbox: VBoxContainer = tree.get_parent()

	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 4)

	new_char_button = Button.new()
	new_char_button.text = "+ New"
	new_char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_char_button.pressed.connect(_on_new_character_pressed)
	action_hbox.add_child(new_char_button)

	copy_char_button = Button.new()
	copy_char_button.text = "Copy From..."
	copy_char_button.disabled = true
	copy_char_button.pressed.connect(_on_copy_character_pressed)
	action_hbox.add_child(copy_char_button)

	rename_char_button = Button.new()
	rename_char_button.text = "Rename"
	rename_char_button.disabled = true
	rename_char_button.pressed.connect(_on_rename_character_pressed)
	action_hbox.add_child(rename_char_button)

	delete_char_button = Button.new()
	delete_char_button.text = "Delete"
	delete_char_button.disabled = true
	delete_char_button.pressed.connect(_on_delete_character_pressed)
	action_hbox.add_child(delete_char_button)

	var refresh_idx := refresh_button.get_index()
	left_vbox.add_child(action_hbox)
	left_vbox.move_child(action_hbox, refresh_idx + 1)

	# ---- New Character Dialog ----
	new_char_dialog = ConfirmationDialog.new()
	new_char_dialog.title = "Create New Character"
	new_char_dialog.size = Vector2i(360, 160)

	var new_vbox := VBoxContainer.new()
	new_vbox.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = "Character File Name:"
	new_vbox.add_child(name_lbl)

	new_char_name_input = LineEdit.new()
	new_char_name_input.placeholder_text = "new_character"
	new_vbox.add_child(new_char_name_input)

	var folder_lbl := Label.new()
	folder_lbl.text = "Target Category Folder:"
	new_vbox.add_child(folder_lbl)

	folder_select_option = OptionButton.new()
	new_vbox.add_child(folder_select_option)

	new_char_dialog.add_child(new_vbox)
	new_char_dialog.confirmed.connect(_confirm_new_character)
	add_child(new_char_dialog)

	# ---- Copy Character Data Dialog ----
	copy_char_dialog = ConfirmationDialog.new()
	copy_char_dialog.title = "Copy Character Data"
	copy_char_dialog.size = Vector2i(360, 120)

	var copy_vbox := VBoxContainer.new()
	copy_vbox.add_theme_constant_override("separation", 8)

	var copy_lbl := Label.new()
	copy_lbl.text = "Select source character to copy from:"
	copy_vbox.add_child(copy_lbl)

	copy_source_option = OptionButton.new()
	copy_vbox.add_child(copy_source_option)

	copy_char_dialog.add_child(copy_vbox)
	copy_char_dialog.confirmed.connect(_on_copy_dialog_confirmed)
	add_child(copy_char_dialog)

	# ---- Copy Safety Confirmation Dialog ----
	copy_confirm_dialog = ConfirmationDialog.new()
	copy_confirm_dialog.title = "Confirm Overwrite?"
	copy_confirm_dialog.confirmed.connect(_execute_copy_data)
	add_child(copy_confirm_dialog)

	# ---- Rename & Move Dialog ----
	rename_char_dialog = ConfirmationDialog.new()
	rename_char_dialog.title = "Rename & Move Character"
	rename_char_dialog.size = Vector2i(360, 160)

	var rename_vbox := VBoxContainer.new()
	rename_vbox.add_theme_constant_override("separation", 8)

	var r_name_lbl := Label.new()
	r_name_lbl.text = "File Name:"
	rename_vbox.add_child(r_name_lbl)

	rename_char_name_input = LineEdit.new()
	rename_vbox.add_child(rename_char_name_input)

	var r_folder_lbl := Label.new()
	r_folder_lbl.text = "Category Folder:"
	rename_vbox.add_child(r_folder_lbl)

	move_folder_select_option = OptionButton.new()
	rename_vbox.add_child(move_folder_select_option)

	rename_char_dialog.add_child(rename_vbox)
	rename_char_dialog.confirmed.connect(_confirm_rename_character)
	add_child(rename_char_dialog)

	# ---- Delete Confirmation Dialog ----
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


func _populate_folder_dropdown(option_btn: OptionButton) -> void:
	option_btn.clear()
	var folders := _scan_character_folders()

	option_btn.add_item("📁 Root (/data/characters)", 0)
	option_btn.set_item_metadata(0, CHAR_DIR)

	for idx in range(folders.size()):
		var folder_name := folders[idx]
		var full_path := CHAR_DIR.path_join(folder_name)
		option_btn.add_item("📂 " + folder_name, idx + 1)
		option_btn.set_item_metadata(idx + 1, full_path)


func _on_new_character_pressed() -> void:
	_populate_folder_dropdown(folder_select_option)
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


func _on_copy_character_pressed() -> void:
	if not current_res:
		return

	copy_source_option.clear()
	var char_paths := _find_resources_recursive(CHAR_DIR)
	char_paths.sort()

	var count := 0
	for path in char_paths:
		if path == current_path:
			continue
		var res = load(path)
		if res is battle_character_base:
			var display_name : String = res.name if res.name != "" else path.get_file()
			copy_source_option.add_item("👤 " + display_name, count)
			copy_source_option.set_item_metadata(count, path)
			count += 1

	if count == 0:
		status_label.text = "No other character files available to copy from!"
		return

	copy_char_dialog.popup_centered()


func _on_copy_dialog_confirmed() -> void:
	var selected_idx := copy_source_option.selected
	if selected_idx < 0:
		return

	var source_path: String = copy_source_option.get_item_metadata(selected_idx)
	var source_res = load(source_path) as battle_character_base

	if not source_res:
		return

	var source_name : String = source_res.name if source_res.name != "" else source_path.get_file()
	var target_name := current_res.name if current_res.name != "" else current_path.get_file()

	copy_confirm_dialog.dialog_text = "Are you sure you want to overwrite all data in '%s' with data from '%s'?\n\n(This will replace stats, skills, behaviours, affinities, sprite name, and growth settings)." % [target_name, source_name]
	copy_confirm_dialog.set_meta("source_path", source_path)
	copy_confirm_dialog.popup_centered()


func _execute_copy_data() -> void:
	var source_path: String = copy_confirm_dialog.get_meta("source_path")
	if source_path == "" or not current_res:
		return

	var source_res = load(source_path) as battle_character_base
	if not source_res:
		return

	_copy_character_data(source_res, current_res)
	_populate_form()
	_on_field_changed(0)
	status_label.text = "Successfully copied data from '%s'!" % (source_res.name if source_res.name != "" else source_path.get_file())


func _copy_character_data(src: battle_character_base, target: battle_character_base) -> void:
	target.character_colour = src.character_colour
	target.turns = src.turns
	target.health = src.health
	target.stamina = src.stamina

	for prop in ["animation_player_loc", "character_sprite", "sprite", "character_sprite_scene"]:
		if prop in src and prop in target:
			target.set(prop, src.get(prop))

	target.stamina_increase_levels = src.stamina_increase_levels.duplicate() if src.stamina_increase_levels != null else []

	if src.stats and target.stats:
		target.stats.strength = src.stats.strength
		target.stats.vitality = src.stats.vitality
		target.stats.dexterity = src.stats.dexterity
		target.stats.magic_pow = src.stats.magic_pow
		target.stats.agility = src.stats.agility
		target.stats.luck = src.stats.luck

	if src.stat_increase and target.stat_increase:
		target.stat_increase.health_min = src.stat_increase.health_min
		target.stat_increase.health_max = src.stat_increase.health_max
		target.stat_increase.strength = src.stat_increase.strength
		target.stat_increase.vitality = src.stat_increase.vitality
		target.stat_increase.dexterity = src.stat_increase.dexterity
		target.stat_increase.magic_pow = src.stat_increase.magic_pow
		target.stat_increase.agility = src.stat_increase.agility
		target.stat_increase.luck = src.stat_increase.luck

	target.base_exp_score = src.base_exp_score
	target.base_exp_to_NL = src.base_exp_to_NL
	target.exp_req_multipler = src.exp_req_multipler

	var src_skills = src.get("character_skills") if "character_skills" in src else src.get("skills")
	if src_skills is Array:
		var copied_skills: Array = src_skills.duplicate()
		if "character_skills" in target:
			target.set("character_skills", copied_skills)
		elif "skills" in target:
			target.set("skills", copied_skills)

	if "override_default_behaviours" in src and "override_default_behaviours" in target:
		target.override_default_behaviours = src.override_default_behaviours

	# Copy chara_behaviour_n
	var new_behaviours_n: Array[battle_ch_bh_perc] = []
	if src.chara_behaviour_n:
		for entry in src.chara_behaviour_n:
			if entry:
				var new_entry := battle_ch_bh_perc.new()
				new_entry.behaviour = entry.behaviour
				new_entry.percentage = entry.percentage
				new_entry.priority = entry.priority
				new_behaviours_n.append(new_entry)
	target.chara_behaviour_n = new_behaviours_n

	var new_potentials: Array[elemental_potential] = []
	if src.elemental_potential:
		for pot in src.elemental_potential:
			if pot:
				var new_pot := elemental_potential.new()
				new_pot.elemental = pot.elemental
				new_pot.potential = pot.potential
				new_potentials.append(new_pot)
	target.elemental_potential = new_potentials

	var new_affinities: Array[elemental_affinity] = []
	if src.elemental_affinities:
		for aff in src.elemental_affinities:
			if aff:
				var new_aff := elemental_affinity.new()
				new_aff.elementalName = aff.elementalName
				new_aff.affinity = aff.affinity
				new_affinities.append(new_aff)
	target.elemental_affinities = new_affinities


func _on_rename_character_pressed() -> void:
	if current_path == "":
		return

	_populate_folder_dropdown(move_folder_select_option)

	var current_file_name := current_path.get_file().get_basename()
	rename_char_name_input.text = current_file_name

	var current_folder := current_path.get_base_dir()
	for i in range(move_folder_select_option.item_count):
		if move_folder_select_option.get_item_metadata(i) == current_folder:
			move_folder_select_option.select(i)
			break

	rename_char_dialog.popup_centered()
	rename_char_name_input.select_all()
	rename_char_name_input.grab_focus()


func _confirm_rename_character() -> void:
	if current_path == "":
		return

	var new_file_name := rename_char_name_input.text.strip_edges()
	if new_file_name == "":
		return

	if not new_file_name.ends_with(".tres") and not new_file_name.ends_with(".res"):
		new_file_name += ".tres"

	var folder_idx := move_folder_select_option.selected
	var target_dir: String = move_folder_select_option.get_item_metadata(folder_idx) if folder_idx >= 0 else CHAR_DIR
	var target_path := target_dir.path_join(new_file_name)

	if target_path == current_path:
		return

	if FileAccess.file_exists(target_path):
		status_label.text = "Error: File '%s' already exists!" % new_file_name
		return

	var err := DirAccess.rename_absolute(current_path, target_path)
	if err == OK:
		status_label.text = "Moved/Renamed character to: " + target_path
		current_path = target_path
		_populate_tree()
		_load_character(current_path)
	else:
		status_label.text = "Failed to rename file (error %d)" % err


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
		rename_char_button.disabled = true
		copy_char_button.disabled = true
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

	# Character Sprite Dropdown
	sprite_select = OptionButton.new()
	sprite_select.item_selected.connect(func(_idx): _on_field_changed(0))
	form_root.add_child(_labeled_row("Character Sprite", sprite_select))

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
	skill_search_edit.placeholder_text = "Search moves..."
	skill_search_edit.text_changed.connect(_on_skill_search_changed)
	form_root.add_child(_labeled_row("Filter Moves", skill_search_edit))

	skill_tab_container = TabContainer.new()
	skill_tab_container.custom_minimum_size = Vector2(0, 260)

	var assigned_scroll := ScrollContainer.new()
	assigned_scroll.name = "Assigned Moves"
	assigned_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	assigned_skills_vbox = VBoxContainer.new()
	assigned_skills_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assigned_skills_vbox.add_theme_constant_override("separation", 6)
	assigned_scroll.add_child(assigned_skills_vbox)

	var unassigned_scroll := ScrollContainer.new()
	unassigned_scroll.name = "Unassigned Moves"
	unassigned_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	unassigned_skills_vbox = VBoxContainer.new()
	unassigned_skills_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unassigned_skills_vbox.add_theme_constant_override("separation", 6)
	unassigned_scroll.add_child(unassigned_skills_vbox)

	skill_tab_container.add_child(assigned_scroll)
	skill_tab_container.add_child(unassigned_scroll)
	form_root.add_child(skill_tab_container)

	skill_cards.clear()
	skill_enable_checks.clear()

	for sk in loaded_skills:
		_create_skill_card_ui(sk)

	form_root.add_child(_hsep())

	# ---- Character Behaviours (chara_behaviour_n) ----
	form_root.add_child(_section_header("Character Behaviours (chara_behaviour_n)"))

	override_behaviour_check = CheckBox.new()
	override_behaviour_check.text = "Override Default Behaviours (Ignore AI Defaults)"
	override_behaviour_check.toggled.connect(func(_t): _on_field_changed(0))
	form_root.add_child(override_behaviour_check)

	behaviour_vbox = VBoxContainer.new()
	behaviour_vbox.add_theme_constant_override("separation", 8)
	form_root.add_child(behaviour_vbox)

	var add_behaviour_btn := Button.new()
	add_behaviour_btn.text = "+ Assign Behaviour Slot"
	add_behaviour_btn.pressed.connect(func():
		_add_behaviour_slot(null, 1.0, 0)
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


func _create_skill_card_ui(sk: rpg_skill) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 0.9)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var enable_cb := CheckBox.new()
	enable_cb.custom_minimum_size = Vector2(30, 0)
	enable_cb.toggled.connect(func(is_checked):
		_move_skill_card_to_tab(sk, is_checked)
		_on_field_changed(0)
	)
	skill_enable_checks[sk] = enable_cb
	row.add_child(enable_cb)

	var elem_res = sk.skill_element if "skill_element" in sk else null
	if elem_res and "icon" in elem_res and elem_res.icon:
		var tr := TextureRect.new()
		tr.texture = elem_res.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(20, 20)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = sk.name
	name_lbl.custom_minimum_size = Vector2(150, 0)
	if elem_res and "colour" in elem_res and elem_res.colour is Color:
		name_lbl.add_theme_color_override("font_color", elem_res.colour)
	elif elem_res and "color" in elem_res and elem_res.color is Color:
		name_lbl.add_theme_color_override("font_color", elem_res.color)
	row.add_child(name_lbl)

	var power_lbl := Label.new()
	var pow_val: int = sk.power if "power" in sk else 0
	power_lbl.text = "Power: " + (str(pow_val) if pow_val > 0 else "Status")
	power_lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(power_lbl)

	var repeat_lbl := Label.new()
	var r_min: int = sk.repeat_min if "repeat_min" in sk else 1
	var r_max: int = sk.repeat_max if "repeat_max" in sk else 1
	var repeat_str := str(r_min) + "x" if r_min == r_max else str(r_min) + "-" + str(r_max) + "x"
	repeat_lbl.text = "Executes: " + repeat_str
	repeat_lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(repeat_lbl)

	card.add_child(row)
	card.set_meta("skill_ref", sk)
	skill_cards[sk] = card

	unassigned_skills_vbox.add_child(card)


func _move_skill_card_to_tab(sk: rpg_skill, is_assigned: bool) -> void:
	if not skill_cards.has(sk):
		return

	var card: Control = skill_cards[sk]
	var parent := card.get_parent()
	if parent:
		parent.remove_child(card)

	if is_assigned:
		assigned_skills_vbox.add_child(card)
	else:
		unassigned_skills_vbox.add_child(card)


func _add_behaviour_slot(selected_beh: battle_chara_behaviour = null, perc_val: float = 1.0, prio_val: int = 0) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 0.9)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)

	var beh_select := OptionButton.new()
	beh_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beh_select.add_item("None (Empty Slot)", 0)

	var match_idx := 0
	for idx in range(loaded_behaviours.size()):
		var beh := loaded_behaviours[idx]
		var path_name := beh.resource_path.get_file().get_basename()
		var display_text := "🧠 " + path_name
		beh_select.add_item(display_text, idx + 1)
		beh_select.set_item_metadata(idx + 1, beh)

		if selected_beh and beh == selected_beh:
			match_idx = idx + 1

	if match_idx > 0:
		beh_select.select(match_idx)

	beh_select.item_selected.connect(func(_idx): _on_field_changed(0))
	row1.add_child(beh_select)

	var del_btn := Button.new()
	del_btn.text = "Remove Slot"
	del_btn.pressed.connect(func():
		card.queue_free()
		_on_field_changed(0)
	)
	row1.add_child(del_btn)
	vbox.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)

	var prio_lbl := Label.new()
	prio_lbl.text = "Priority:"
	row2.add_child(prio_lbl)

	var prio_spin := SpinBox.new()
	prio_spin.min_value = -99
	prio_spin.max_value = 99
	prio_spin.value = prio_val
	prio_spin.value_changed.connect(func(_v): _on_field_changed(0))
	row2.add_child(prio_spin)

	var perc_lbl := Label.new()
	perc_lbl.text = "Weight: %d%%" % int(perc_val * 100)
	perc_lbl.custom_minimum_size = Vector2(90, 0)
	row2.add_child(perc_lbl)

	var perc_slider := HSlider.new()
	perc_slider.min_value = 0.0
	perc_slider.max_value = 1.0
	perc_slider.step = 0.01
	perc_slider.value = perc_val
	perc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perc_slider.value_changed.connect(func(v):
		perc_lbl.text = "Weight: %d%%" % int(v * 100)
		_on_field_changed(0)
	)
	row2.add_child(perc_slider)

	vbox.add_child(row2)
	card.add_child(vbox)

	card.set_meta("beh_select", beh_select)
	card.set_meta("prio_spin", prio_spin)
	card.set_meta("perc_slider", perc_slider)

	behaviour_vbox.add_child(card)


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
	for sk in skill_cards.keys():
		var card: Control = skill_cards[sk]
		if filter == "" or sk.name.to_lower().contains(filter):
			card.visible = true
		else:
			card.visible = false


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	if is_instance_valid(delete_char_button):
		delete_char_button.disabled = not enabled
	if is_instance_valid(rename_char_button):
		rename_char_button.disabled = not enabled
	if is_instance_valid(copy_char_button):
		copy_char_button.disabled = not enabled
	if is_instance_valid(affinity_display):
		affinity_display.is_editable = enabled
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child == affinity_display:
			continue
		if child is SpinBox or child is LineEdit:
			child.editable = enabled
		elif child is ColorPickerButton or child is Button or child is CheckBox or child is OptionButton:
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


func _load_sprites() -> void:
	loaded_sprite_names.clear()
	if not DirAccess.dir_exists_absolute(SPRITE_DIR):
		DirAccess.make_dir_recursive_absolute(SPRITE_DIR)

	var paths := _find_resources_recursive(SPRITE_DIR)
	paths.sort()
	for p in paths:
		if p.ends_with(".tscn") or p.ends_with(".scn") or p.ends_with(".tres") or p.ends_with(".res"):
			var base_name := p.get_file().get_basename()
			loaded_sprite_names.append({
				"display_name": base_name,
				"sprite_name": base_name,
				"full_path": p
			})


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
			elif file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
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
	_load_sprites()
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	delete_char_button.disabled = false
	rename_char_button.disabled = false
	copy_char_button.disabled = false
	status_label.text = "Editing: " + current_res.name


func _populate_form() -> void:
	suppress_signals = true

	name_edit.text = current_res.name
	colour_edit.color = current_res.character_colour
	turns_edit.value = current_res.turns
	health_edit.value = current_res.health
	stamina_edit.value = current_res.stamina

	_refresh_sprite_dropdown_options()

	var current_sprite_str := ""
	for prop in ["animation_player_loc", "character_sprite", "sprite", "character_sprite_scene"]:
		if prop in current_res and current_res.get(prop) is String:
			current_sprite_str = current_res.get(prop)
			if current_sprite_str != "":
				break

	if current_sprite_str != "":
		var clean_sprite_name := current_sprite_str.get_file().get_basename() if "/" in current_sprite_str or "." in current_sprite_str else current_sprite_str

		var match_idx := 0
		for i in range(1, sprite_select.get_item_count()):
			if sprite_select.get_item_metadata(i) == clean_sprite_name:
				match_idx = i
				break

		if match_idx == 0:
			var new_idx := sprite_select.get_item_count()
			sprite_select.add_item("🎬 (Custom/Missing) " + clean_sprite_name, new_idx)
			sprite_select.set_item_metadata(new_idx, clean_sprite_name)
			match_idx = new_idx

		sprite_select.select(match_idx)

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

		if skill_enable_checks.has(sk):
			skill_enable_checks[sk].button_pressed = has_skill
			_move_skill_card_to_tab(sk, has_skill)

	if "override_default_behaviours" in current_res:
		override_behaviour_check.button_pressed = current_res.override_default_behaviours
	else:
		override_behaviour_check.button_pressed = false

	for child in behaviour_vbox.get_children():
		child.queue_free()

	if current_res.chara_behaviour_n:
		for entry in current_res.chara_behaviour_n:
			if entry:
				_add_behaviour_slot(entry.behaviour, entry.percentage, entry.priority)

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

	var chosen_sprite_name: String = sprite_select.get_item_metadata(sprite_select.selected) if sprite_select.selected > 0 else ""

	for prop in ["animation_player_loc", "character_sprite", "sprite", "character_sprite_scene"]:
		if prop in current_res:
			current_res.set(prop, chosen_sprite_name)

	var levels: Array[int] = []
	for spin in stamina_level_spins:
		if is_instance_valid(spin):
			levels.append(int(spin.value))
	current_res.stamina_increase_levels = levels

	var new_character_skills: Array = []
	for sk in loaded_skills:
		if skill_enable_checks.has(sk) and skill_enable_checks[sk].button_pressed:
			new_character_skills.append(sk)

	if "character_skills" in current_res:
		current_res.set("character_skills", new_character_skills)
	elif "skills" in current_res:
		current_res.set("skills", new_character_skills)

	if "override_default_behaviours" in current_res:
		current_res.override_default_behaviours = override_behaviour_check.button_pressed

	var assigned_behaviours_n: Array[battle_ch_bh_perc] = []
	for card in behaviour_vbox.get_children():
		var beh_select: OptionButton = card.get_meta("beh_select")
		var prio_spin: SpinBox = card.get_meta("prio_spin")
		var perc_slider: HSlider = card.get_meta("perc_slider")

		if beh_select and beh_select.selected > 0:
			var selected_beh: battle_chara_behaviour = beh_select.get_item_metadata(beh_select.selected)
			if selected_beh:
				var entry := battle_ch_bh_perc.new()
				entry.behaviour = selected_beh
				entry.percentage = perc_slider.value
				entry.priority = int(prio_spin.value)
				assigned_behaviours_n.append(entry)

	current_res.chara_behaviour_n = assigned_behaviours_n

	for stat_name in stat_edits.keys():
		current_res.stats.set(stat_name, int(stat_edits[stat_name].value))

	current_res.stat_increase.health_min = int(health_min_edit.value)
	current_res.stat_increase.health_max = int(health_max_edit.value)
	for stat_name in increase_edits.keys():
		increase_edits[stat_name].value = increase_edits[stat_name].value

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
