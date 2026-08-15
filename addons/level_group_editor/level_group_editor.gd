# res://addons/level_group_editor/level_group_editor.gd
@tool
extends Control

const LEVEL_DIR := "res://data/levels/"
const GROUP_DIR := "res://data/groups/"
const CHAR_DIR := "res://data/characters"
const SKILL_DIR := "res://data/skills"
const FLAG_DIR := "res://data/flags"

@onready var subgroup_select: OptionButton = %SubgroupSelect
@onready var search_bar: LineEdit = %SearchBar
@onready var refresh_button: Button = %RefreshButton
@onready var new_subgroup_button: Button = %NewSubgroupButton
@onready var new_level_group_button: Button = %NewLevelGroupButton
@onready var level_list: ItemList = %LevelList

@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

var current_path: String = ""
var current_res: battle_level_group = null

var loaded_subgroups: Array[String] = []  
var loaded_level_groups: Array[battle_level_group] = []
var loaded_battle_groups: Array[battle_group_data] = []
var loaded_characters: Array[battle_character_base] = []
var loaded_skills: Array[rpg_skill] = []
var loaded_flags: Array[global_flag] = []

# Core UI Fields
var name_edit: LineEdit
var self_destruct_check: CheckBox
var type_battle_select: OptionButton
var terminal_check: CheckBox
var terminal_scene_edit: LineEdit
var colour_bg_picker: ColorPickerButton
var texture_bg_edit: LineEdit
var pos_x_spin: SpinBox
var pos_y_spin: SpinBox

# Containers for nested objects
var battle_groups_vbox: VBoxContainer
var bg_search_bar: LineEdit

var selected_unlocks: Array[battle_level_group] = []
var selected_removes: Array[battle_level_group] = []
var unlocks_active_vbox: VBoxContainer
var removes_active_vbox: VBoxContainer

var suppress_signals: bool = false
var dirty: bool = false


func _ready() -> void:
	if not is_instance_valid(level_list):
		return

	refresh_button.pressed.connect(_refresh_all)
	search_bar.text_changed.connect(func(_q): _filter_and_populate_levels())
	subgroup_select.item_selected.connect(func(_idx): _filter_and_populate_levels())
	level_list.item_selected.connect(_on_level_selected)

	new_subgroup_button.pressed.connect(_on_new_subgroup_pressed)
	new_level_group_button.pressed.connect(_on_new_level_group_pressed)

	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	_build_form()
	_set_form_enabled(false)
	call_deferred("_refresh_all")


func _refresh_all() -> void:
	_load_subgroups()
	_load_all_reference_data()
	_filter_and_populate_levels()


# ---- Subgroup Dropdown & Level Filtering ----
func _load_subgroups() -> void:
	loaded_subgroups.clear()
	subgroup_select.clear()

	subgroup_select.add_item("📁 All Subgroups", 0)
	subgroup_select.set_item_metadata(0, LEVEL_DIR)

	_scan_subgroups_recursive(LEVEL_DIR)

	for idx in range(loaded_subgroups.size()):
		var sub_path := loaded_subgroups[idx]
		var rel_path := sub_path.replace(LEVEL_DIR, "")
		if rel_path.begins_with("/"):
			rel_path = rel_path.substr(1)
		subgroup_select.add_item("📂 " + rel_path, idx + 1)
		subgroup_select.set_item_metadata(idx + 1, sub_path)


func _scan_subgroups_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(dir_path)
		dir = DirAccess.open(dir_path)
		if not dir:
			return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				loaded_subgroups.append(full_path)
				_scan_subgroups_recursive(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _filter_and_populate_levels() -> void:
	level_list.clear()

	var selected_idx := subgroup_select.selected
	var target_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else LEVEL_DIR
	var search_filter := search_bar.text.strip_edges().to_lower()

	var paths := _find_resources_recursive(target_dir)
	paths.sort()

	for file_path in paths:
		var res = load(file_path)
		if res is battle_level_group:
			var display_name : String = res.name if res.name != "" else file_path.get_file()
			var matches_search := (search_filter == "" or display_name.to_lower().contains(search_filter) or file_path.get_file().to_lower().contains(search_filter))

			if matches_search:
				var item_idx := level_list.add_item("⚔️ " + display_name)
				level_list.set_item_metadata(item_idx, file_path)

				if file_path == current_path:
					level_list.select(item_idx)

	var folder_name := target_dir.get_file()
	if target_dir == LEVEL_DIR or folder_name == "":
		new_level_group_button.text = "+ New Level Group (Root)"
	else:
		new_level_group_button.text = "+ New Level Group in '" + folder_name + "'"


func _on_level_selected(index: int) -> void:
	var path: String = level_list.get_item_metadata(index)
	if path != "":
		_load_level_group(path)


func _navigate_to_level_group(target_lg: battle_level_group) -> void:
	if not target_lg or target_lg.resource_path == "":
		return

	var target_path := target_lg.resource_path

	subgroup_select.select(0)
	search_bar.clear()
	_filter_and_populate_levels()

	for idx in range(level_list.get_item_count()):
		if level_list.get_item_metadata(idx) == target_path:
			level_list.select(idx)
			break

	_load_level_group(target_path)


# ---- New Creation Actions ----
func _on_new_subgroup_pressed() -> void:
	var selected_idx := subgroup_select.selected
	var parent_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else LEVEL_DIR

	var new_folder_name := "subgroup_" + str(Time.get_unix_time_from_system())
	var full_folder_path := parent_dir.path_join(new_folder_name)

	var dir_err := DirAccess.make_dir_recursive_absolute(full_folder_path)
	if dir_err == OK:
		_refresh_all()
		status_label.text = "Created subgroup folder: " + new_folder_name
	else:
		status_label.text = "Failed to create subgroup folder (error %d)" % dir_err


func _on_new_level_group_pressed() -> void:
	var selected_idx := subgroup_select.selected
	var parent_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else LEVEL_DIR

	var base_filename := "new_battle_level_group"
	var file_path := parent_dir.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = parent_dir.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_res := battle_level_group.new()
	new_res.name = "New Level Group " + str(count)
	new_res.type_battle = battle_level_group.battle_type.NORMAL
	new_res.self_destruct_after_win = true

	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		_refresh_all()
		_load_level_group(file_path)
		status_label.text = "Created new level group at: " + file_path
	else:
		status_label.text = "Failed to create level group (error %d)" % err


# ---- Form UI Builders ----
func _section_header(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.22, 0.8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(l)
	return panel


func _labeled_row(label_text: String, control: Control, label_width: int = 160) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _make_int_spin(min_v: float, max_v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1.0
	s.value_changed.connect(func(_v): _on_field_changed())
	return s


func _build_form() -> void:
	for c in form_root.get_children():
		c.queue_free()

	form_root.add_child(_section_header("Level Group Configuration"))

	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Level Group Name", name_edit))

	type_battle_select = OptionButton.new()
	type_battle_select.add_item("BOSS", 0)
	type_battle_select.add_item("NORMAL", 1)
	type_battle_select.add_item("MINI_BOSS", 2)
	type_battle_select.add_item("HARD", 3)
	type_battle_select.add_item("MEDIUM", 4)
	type_battle_select.add_item("EASY", 5)
	type_battle_select.item_selected.connect(func(_idx): _on_field_changed())
	form_root.add_child(_labeled_row("Battle Type", type_battle_select))

	self_destruct_check = CheckBox.new()
	self_destruct_check.text = "Self Destruct After Win (Not Replayable)"
	self_destruct_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Replayability", self_destruct_check))

	form_root.add_child(HSeparator.new())

	form_root.add_child(_section_header("Terminal & Visual Presentation"))

	terminal_check = CheckBox.new()
	terminal_check.text = "Is Terminal Level"
	terminal_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Terminal Flag", terminal_check))

	terminal_scene_edit = LineEdit.new()
	terminal_scene_edit.placeholder_text = "res://scenes/terminals/terminal_end.tscn"
	terminal_scene_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Terminal Scene Path", terminal_scene_edit))

	colour_bg_picker = ColorPickerButton.new()
	colour_bg_picker.custom_minimum_size = Vector2(0, 26)
	colour_bg_picker.color_changed.connect(func(_c): _on_field_changed())
	form_root.add_child(_labeled_row("Background Color", colour_bg_picker))

	texture_bg_edit = LineEdit.new()
	texture_bg_edit.placeholder_text = "res://sprites/backgrounds/forest_bg.png"
	texture_bg_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Background Texture Path", texture_bg_edit))

	var pos_row := HBoxContainer.new()
	pos_x_spin = _make_int_spin(-9999, 9999)
	pos_y_spin = _make_int_spin(-9999, 9999)
	pos_row.add_child(Label.new())
	pos_row.get_child(0).text = "X:"
	pos_row.add_child(pos_x_spin)
	pos_row.add_child(Label.new())
	pos_row.get_child(2).text = "Y:"
	pos_row.add_child(pos_y_spin)
	form_root.add_child(_labeled_row("Editor Node Position", pos_row))

	form_root.add_child(HSeparator.new())

	# ---- Battle Groups Sequence Section ----
	form_root.add_child(_section_header("Battle Groups Sequence"))
	
	bg_search_bar = LineEdit.new()
	bg_search_bar.placeholder_text = "Filter battle group references below..."
	bg_search_bar.clear_button_enabled = true
	bg_search_bar.text_changed.connect(func(q): _filter_battle_group_cards(q))
	form_root.add_child(_labeled_row("Filter Battle Groups", bg_search_bar))

	battle_groups_vbox = VBoxContainer.new()
	battle_groups_vbox.add_theme_constant_override("separation", 10)
	form_root.add_child(battle_groups_vbox)

	var bg_btn_row := HBoxContainer.new()
	bg_btn_row.add_theme_constant_override("separation", 8)

	var add_bg_btn := Button.new()
	add_bg_btn.text = "+ Add Existing Group Reference"
	add_bg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_bg_btn.pressed.connect(func():
		_add_battle_group_card()
		_on_field_changed()
	)
	bg_btn_row.add_child(add_bg_btn)

	var create_new_bg_file_btn := Button.new()
	create_new_bg_file_btn.text = "+ Create New .tres Group File"
	create_new_bg_file_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_new_bg_file_btn.pressed.connect(_on_create_new_battle_group_file)
	bg_btn_row.add_child(create_new_bg_file_btn)

	form_root.add_child(bg_btn_row)

	form_root.add_child(HSeparator.new())

	# ---- Progression Unlocks & Removals Section ----
	form_root.add_child(_section_header("Level Progression Unlocks & Removals"))

	# 1. Unlocks Builder
	var unlocks_box := VBoxContainer.new()
	var add_unlock_select := OptionButton.new()
	add_unlock_select.add_item("+ Select Level Group to Unlock...", 0)
	add_unlock_select.item_selected.connect(func(idx):
		if idx > 0:
			var target_lg: battle_level_group = add_unlock_select.get_item_metadata(idx)
			if target_lg and not selected_unlocks.has(target_lg):
				selected_unlocks.append(target_lg)
				_render_active_unlocks()
				_on_field_changed()
			add_unlock_select.select(0)
	)
	unlocks_box.add_child(add_unlock_select)
	unlocks_box.set_meta("select_node", add_unlock_select)

	unlocks_active_vbox = VBoxContainer.new()
	unlocks_box.add_child(unlocks_active_vbox)
	form_root.add_child(_labeled_row("Unlock Level Groups", unlocks_box))

	# 2. Removals Builder
	var removes_box := VBoxContainer.new()
	var add_remove_select := OptionButton.new()
	add_remove_select.add_item("+ Select Level Group to Remove...", 0)
	add_remove_select.item_selected.connect(func(idx):
		if idx > 0:
			var target_lg: battle_level_group = add_remove_select.get_item_metadata(idx)
			if target_lg and not selected_removes.has(target_lg):
				selected_removes.append(target_lg)
				_render_active_removes()
				_on_field_changed()
			add_remove_select.select(0)
	)
	removes_box.add_child(add_remove_select)
	removes_box.set_meta("select_node", add_remove_select)

	removes_active_vbox = VBoxContainer.new()
	removes_box.add_child(removes_active_vbox)
	form_root.add_child(_labeled_row("Remove Level Groups", removes_box))


# ---- Data Loading & References ----
func _load_all_reference_data() -> void:
	loaded_level_groups.clear()
	for p in _find_resources_recursive(LEVEL_DIR):
		var res = load(p)
		if res is battle_level_group and res != current_res:
			loaded_level_groups.append(res)

	loaded_battle_groups.clear()
	for p in _find_resources_recursive(GROUP_DIR):
		var res = load(p)
		if res is battle_group_data:
			loaded_battle_groups.append(res)

	loaded_characters.clear()
	for p in _find_resources_recursive(CHAR_DIR):
		var res = load(p)
		if res is battle_character_base:
			loaded_characters.append(res)

	loaded_skills.clear()
	for p in _find_resources_recursive(SKILL_DIR):
		var res = load(p)
		if res is rpg_skill:
			loaded_skills.append(res)

	loaded_flags.clear()
	for p in _find_resources_recursive(FLAG_DIR):
		var res = load(p)
		if res is global_flag:
			loaded_flags.append(res)


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


func _load_level_group(path: String) -> void:
	current_path = path
	current_res = load(path)
	_load_all_reference_data()
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	status_label.text = "Editing: " + current_res.name


func _populate_form() -> void:
	suppress_signals = true

	name_edit.text = current_res.name
	type_battle_select.select(current_res.type_battle)
	self_destruct_check.button_pressed = current_res.self_destruct_after_win
	terminal_check.button_pressed = current_res.terminal
	terminal_scene_edit.text = current_res.terminal_scene
	colour_bg_picker.color = current_res.colour_BG
	texture_bg_edit.text = current_res.texture_BG.resource_path if current_res.texture_BG else ""
	pos_x_spin.value = current_res.editor_position.x
	pos_y_spin.value = current_res.editor_position.y

	selected_unlocks = current_res.battle_groups_unlock.duplicate()
	selected_removes = current_res.battle_groups_remove.duplicate()

	_populate_progression_dropdowns()
	_render_active_unlocks()
	_render_active_removes()

	for c in battle_groups_vbox.get_children():
		c.queue_free()

	if current_res.battle_groups:
		for bg_data in current_res.battle_groups:
			_add_battle_group_card(bg_data)

	suppress_signals = false


func _populate_progression_dropdowns() -> void:
	var u_select: OptionButton = unlocks_active_vbox.get_parent().get_meta("select_node")
	var r_select: OptionButton = removes_active_vbox.get_parent().get_meta("select_node")

	u_select.clear()
	r_select.clear()

	u_select.add_item("+ Select Level Group to Unlock...", 0)
	r_select.add_item("+ Select Level Group to Remove...", 0)

	for idx in range(loaded_level_groups.size()):
		var lg := loaded_level_groups[idx]
		var item_idx := idx + 1
		u_select.add_item("⚔️ " + lg.name, item_idx)
		u_select.set_item_metadata(item_idx, lg)

		r_select.add_item("⚔️ " + lg.name, item_idx)
		r_select.set_item_metadata(item_idx, lg)


func _render_active_unlocks() -> void:
	for c in unlocks_active_vbox.get_children():
		c.queue_free()

	for lg in selected_unlocks:
		var tag := HBoxContainer.new()
		
		var link_btn := Button.new()
		link_btn.text = "⚔️ " + lg.name
		link_btn.flat = true
		link_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link_btn.add_theme_color_override("font_color", Color.CYAN)
		link_btn.pressed.connect(func(): _navigate_to_level_group(lg))
		tag.add_child(link_btn)

		var btn := Button.new()
		btn.text = "X"
		btn.pressed.connect(func():
			selected_unlocks.erase(lg)
			_render_active_unlocks()
			_on_field_changed()
		)
		tag.add_child(btn)
		unlocks_active_vbox.add_child(tag)


func _render_active_removes() -> void:
	for c in removes_active_vbox.get_children():
		c.queue_free()

	for lg in selected_removes:
		var tag := HBoxContainer.new()
		
		var link_btn := Button.new()
		link_btn.text = "⚔️ " + lg.name
		link_btn.flat = true
		link_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link_btn.add_theme_color_override("font_color", Color.CYAN)
		link_btn.pressed.connect(func(): _navigate_to_level_group(lg))
		tag.add_child(link_btn)

		var btn := Button.new()
		btn.text = "X"
		btn.pressed.connect(func():
			selected_removes.erase(lg)
			_render_active_removes()
			_on_field_changed()
		)
		tag.add_child(btn)
		removes_active_vbox.add_child(tag)


func _on_create_new_battle_group_file() -> void:
	var base_filename := "new_battle_group"
	var file_path := GROUP_DIR.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = GROUP_DIR.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_bg := battle_group_data.new()
	var err := ResourceSaver.save(new_bg, file_path)
	if err == OK:
		_load_all_reference_data()
		_add_battle_group_card(new_bg)
		_on_field_changed()
		status_label.text = "Created new group file: " + file_path
	else:
		status_label.text = "Failed to create group file (error %d)" % err


func _filter_battle_group_cards(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for card in battle_groups_vbox.get_children():
		if filter == "":
			card.visible = true
			continue

		var card_vbox: Control = card.get_child(0) if card.get_child_count() > 0 else null
		var header_row: Control = card_vbox.get_child(0) if card_vbox and card_vbox.get_child_count() > 0 else null
		var bg_select: OptionButton = header_row.get_child(0) if header_row and header_row.get_child_count() > 0 else null

		if bg_select and bg_select.selected >= 0:
			var item_text := bg_select.get_item_text(bg_select.selected).to_lower()
			card.visible = item_text.contains(filter)


# ---- Detailed Group Card Visualizer ----
func _add_battle_group_card(selected_bg: battle_group_data = null) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 0.9)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	var header_row := HBoxContainer.new()
	var bg_select := OptionButton.new()
	bg_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for idx in range(loaded_battle_groups.size()):
		var bg := loaded_battle_groups[idx]
		var bg_name := bg.resource_path.get_file().get_basename()
		bg_select.add_item(bg_name, idx)
		bg_select.set_item_metadata(idx, bg)

	if selected_bg:
		var idx := loaded_battle_groups.find(selected_bg)
		if idx != -1:
			bg_select.select(idx)

	header_row.add_child(bg_select)

	var rem_btn := Button.new()
	rem_btn.text = "Remove From Level"
	rem_btn.pressed.connect(func():
		card.queue_free()
		_on_field_changed()
	)
	header_row.add_child(rem_btn)
	card_vbox.add_child(header_row)

	var details_vbox := VBoxContainer.new()
	card_vbox.add_child(details_vbox)

	var update_details := func(bg_res: battle_group_data):
		for child in details_vbox.get_children():
			child.queue_free()

		if not bg_res:
			return

		var opp_label := RichTextLabel.new()
		opp_label.fit_content = true
		opp_label.bbcode_enabled = true

		var opp_txt := "[b]Opponents / Members (%d):[/b]\n" % bg_res.opponents.size()
		if bg_res.opponents.size() == 0:
			opp_txt += "• [color=gray]No members defined in group.[/color]\n"
		else:
			for m in bg_res.opponents:
				var c_name := m.character.name if m.character else "Unknown Character"
				var skill_names := []
				for sk in m.skills:
					if sk: skill_names.append(sk.name)

				var skills_str := ", ".join(skill_names) if skill_names.size() > 0 else "No Skills"
				var perma_str := " [color=red](PermaDeath)[/color]" if m.perma_death else ""

				opp_txt += "• [color=cyan]%s[/color] (Lvl %d-%d) | Skills: %s%s\n" % [
					c_name, m.min_level, m.max_level, skills_str, perma_str
				]

		opp_label.text = opp_txt
		details_vbox.add_child(opp_label)

		var rew_label := RichTextLabel.new()
		rew_label.fit_content = true
		rew_label.bbcode_enabled = true

		var rew_txt := "[b]Rewards (%d):[/b]\n" % bg_res.rewards.size()
		if bg_res.rewards.size() == 0:
			rew_txt += "• [color=gray]No rewards defined in group.[/color]"
		else:
			for r in bg_res.rewards:
				var display_str := r.display_reward()
				if display_str == "" and r.has_method("return_message"):
					display_str = r.return_message()
				if display_str == "":
					display_str = r.get_script().get_global_name()

				rew_txt += "• %s\n" % display_str

		rew_label.text = rew_txt
		details_vbox.add_child(rew_label)

	bg_select.item_selected.connect(func(selected_idx):
		var bg_res: battle_group_data = bg_select.get_item_metadata(selected_idx)
		update_details.call(bg_res)
		_on_field_changed()
	)

	if bg_select.selected >= 0:
		var bg_res: battle_group_data = bg_select.get_item_metadata(bg_select.selected)
		update_details.call(bg_res)

	battle_groups_vbox.add_child(card)


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit:
			child.editable = enabled
		elif child is ColorPickerButton or child is Button or child is CheckBox or child is OptionButton or child is MenuButton:
			child.disabled = not enabled
		else:
			_set_container_editable(child, enabled)


func _on_field_changed() -> void:
	if suppress_signals or not current_res:
		return
	dirty = true
	save_button.disabled = false
	revert_button.disabled = false
	status_label.text = "Unsaved changes to '" + current_res.name + "'"


func _on_save_pressed() -> void:
	if not current_res:
		return

	current_res.name = name_edit.text
	current_res.type_battle = type_battle_select.selected as battle_level_group.battle_type
	current_res.self_destruct_after_win = self_destruct_check.button_pressed
	current_res.terminal = terminal_check.button_pressed
	current_res.terminal_scene = terminal_scene_edit.text
	current_res.colour_BG = colour_bg_picker.color
	if texture_bg_edit.text != "" and ResourceLoader.exists(texture_bg_edit.text):
		current_res.texture_BG = load(texture_bg_edit.text)
	current_res.editor_position = Vector2(pos_x_spin.value, pos_y_spin.value)

	var bg_list: Array[battle_group_data] = []
	for card in battle_groups_vbox.get_children():
		var card_vbox: Control = card.get_child(0) if card.get_child_count() > 0 else null
		var header_row: Control = card_vbox.get_child(0) if card_vbox and card_vbox.get_child_count() > 0 else null
		if header_row:
			var bg_select: OptionButton = header_row.get_child(0)
			if bg_select and bg_select.selected >= 0:
				var bg_res: battle_group_data = bg_select.get_item_metadata(bg_select.selected)
				if bg_res:
					bg_list.append(bg_res)
	current_res.battle_groups = bg_list

	current_res.battle_groups_unlock = selected_unlocks.duplicate()
	current_res.battle_groups_remove = selected_removes.duplicate()

	var err := ResourceSaver.save(current_res, current_path)
	if err == OK:
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "Saved '" + current_res.name + "' to disk."
		_filter_and_populate_levels()
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
