# res://addons/battle_group_editor/battle_group_editor.gd
@tool
extends Control

const GROUP_DIR := "res://data/groups/"
const CHAR_DIR := "res://data/characters"
const SKILL_DIR := "res://data/skills"
const FLAG_DIR := "res://data/flags"

@onready var subgroup_select: OptionButton = %SubgroupSelect
@onready var search_bar: LineEdit = %SearchBar
@onready var refresh_button: Button = %RefreshButton
@onready var new_subgroup_button: Button = %NewSubgroupButton
@onready var new_group_button: Button = %NewGroupButton
@onready var group_list: ItemList = %GroupList

@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

var current_path: String = ""
var current_res: battle_group_data = null

var loaded_subgroups: Array[String] = []
var loaded_characters: Array[battle_character_base] = []
var loaded_skills: Array[rpg_skill] = []
var loaded_flags: Array[global_flag] = []

# Dynamic Containers
var group_type_select: OptionButton
var members_vbox: VBoxContainer
var preset_header: PanelContainer
var preset_vbox: VBoxContainer
var add_preset_btn: Button
var rewards_vbox: VBoxContainer

var suppress_signals: bool = false
var dirty: bool = false


func _ready() -> void:
	if not is_instance_valid(group_list):
		return

	refresh_button.pressed.connect(_refresh_all)
	search_bar.text_changed.connect(func(_q): _filter_and_populate_groups())
	subgroup_select.item_selected.connect(func(_idx): _filter_and_populate_groups())
	group_list.item_selected.connect(_on_group_selected)

	new_subgroup_button.pressed.connect(_on_new_subgroup_pressed)
	new_group_button.pressed.connect(_on_new_group_pressed)

	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	_build_form()
	_set_form_enabled(false)
	call_deferred("_refresh_all")


func _refresh_all() -> void:
	_load_subgroups()
	_load_all_reference_data()
	_filter_and_populate_groups()


func _load_subgroups() -> void:
	loaded_subgroups.clear()
	subgroup_select.clear()

	subgroup_select.add_item("📁 All Subgroups", 0)
	subgroup_select.set_item_metadata(0, GROUP_DIR)

	_scan_subgroups_recursive(GROUP_DIR)

	for idx in range(loaded_subgroups.size()):
		var sub_path := loaded_subgroups[idx]
		var rel_path := sub_path.replace(GROUP_DIR, "")
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


func _filter_and_populate_groups() -> void:
	group_list.clear()

	var selected_idx := subgroup_select.selected
	var target_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else GROUP_DIR
	var search_filter := search_bar.text.strip_edges().to_lower()

	var paths := _find_resources_recursive(target_dir)
	paths.sort()

	for file_path in paths:
		var res = load(file_path)
		if res is battle_group_data:
			var display_name := file_path.get_file().get_basename()
			var matches_search := (search_filter == "" or display_name.to_lower().contains(search_filter))

			if matches_search:
				var item_idx := group_list.add_item(display_name)
				group_list.set_item_metadata(item_idx, file_path)

				if file_path == current_path:
					group_list.select(item_idx)

	var folder_name := target_dir.get_file()
	if target_dir == GROUP_DIR or folder_name == "":
		new_group_button.text = "+ New Battle Group (Root)"
	else:
		new_group_button.text = "+ New Battle Group in '" + folder_name + "'"


func _on_group_selected(index: int) -> void:
	var path: String = group_list.get_item_metadata(index)
	if path != "":
		_load_group(path)


func _on_new_subgroup_pressed() -> void:
	var selected_idx := subgroup_select.selected
	var parent_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else GROUP_DIR

	var new_folder_name := "group_subfolder_" + str(Time.get_unix_time_from_system())
	var full_folder_path := parent_dir.path_join(new_folder_name)

	var dir_err := DirAccess.make_dir_recursive_absolute(full_folder_path)
	if dir_err == OK:
		_refresh_all()
		status_label.text = "Created subgroup folder: " + new_folder_name
	else:
		status_label.text = "Failed to create folder (error %d)" % dir_err


func _on_new_group_pressed() -> void:
	var selected_idx := subgroup_select.selected
	var parent_dir: String = subgroup_select.get_item_metadata(selected_idx) if selected_idx >= 0 else GROUP_DIR

	var base_filename := "new_battle_group"
	var file_path := parent_dir.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = parent_dir.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_res := battle_group_data.new()
	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		_refresh_all()
		_load_group(file_path)
		status_label.text = "Created new group file at: " + file_path
	else:
		status_label.text = "Failed to create group file (error %d)" % err


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


func _build_form() -> void:
	for c in form_root.get_children():
		c.queue_free()

	# ---- Type Conversion Selector ----
	form_root.add_child(_section_header("Resource Type"))

	var type_row := HBoxContainer.new()
	var type_lbl := Label.new()
	type_lbl.text = "Group Type:"
	type_lbl.custom_minimum_size = Vector2(160, 0)
	type_row.add_child(type_lbl)

	group_type_select = OptionButton.new()
	group_type_select.add_item("Standard Battle Group (battle_group_data)", 0)
	group_type_select.add_item("Preset Party Group (present_group_data)", 1)
	group_type_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_type_select.item_selected.connect(_on_group_type_changed)
	type_row.add_child(group_type_select)
	form_root.add_child(type_row)

	form_root.add_child(HSeparator.new())

	# ---- Members / Opponents Section ----
	form_root.add_child(_section_header("Group Opponents (opponents)"))
	
	members_vbox = VBoxContainer.new()
	members_vbox.add_theme_constant_override("separation", 10)
	form_root.add_child(members_vbox)

	var add_member_btn := Button.new()
	add_member_btn.text = "+ Add Opponent Member"
	add_member_btn.pressed.connect(func():
		_add_member_card(null, members_vbox)
		_on_field_changed()
	)
	form_root.add_child(add_member_btn)

	form_root.add_child(HSeparator.new())

	# ---- Exclusive Preset Members Section ----
	preset_header = _section_header("Temporary Preset Party Members (preset_members)")
	form_root.add_child(preset_header)

	preset_vbox = VBoxContainer.new()
	preset_vbox.add_theme_constant_override("separation", 10)
	form_root.add_child(preset_vbox)

	add_preset_btn = Button.new()
	add_preset_btn.text = "+ Add Preset Party Member"
	add_preset_btn.pressed.connect(func():
		_add_member_card(null, preset_vbox)
		_on_field_changed()
	)
	form_root.add_child(add_preset_btn)

	# ---- Rewards Section ----
	form_root.add_child(HSeparator.new())
	form_root.add_child(_section_header("Group Completion Rewards (rewards)"))

	rewards_vbox = VBoxContainer.new()
	rewards_vbox.add_theme_constant_override("separation", 8)
	form_root.add_child(rewards_vbox)

	var add_reward_btn := MenuButton.new()
	add_reward_btn.text = "+ Add Completion Reward..."
	var popup := add_reward_btn.get_popup()
	popup.add_item("Character Join Reward (reward_character)", 0)
	popup.add_item("Flag Change Reward (reward_change_flag)", 1)
	popup.add_item("Extra Skill Limit Reward (reward_extra_skill_count)", 2)
	
	popup.id_pressed.connect(func(id):
		match id:
			0: _add_reward_card(reward_character.new())
			1: _add_reward_card(reward_change_flag.new())
			2: _add_reward_card(reward_extra_skill_count.new())
		_on_field_changed()
	)
	form_root.add_child(add_reward_btn)


func _update_preset_visibility(is_preset: bool) -> void:
	if is_instance_valid(preset_header):
		preset_header.visible = is_preset
	if is_instance_valid(preset_vbox):
		preset_vbox.visible = is_preset
	if is_instance_valid(add_preset_btn):
		add_preset_btn.visible = is_preset


func _on_group_type_changed(idx: int) -> void:
	if not current_res or current_path == "":
		return

	var want_preset := (idx == 1)
	var is_preset := (current_res is present_group_data)

	if want_preset == is_preset:
		return

	_apply_ui_to_resource()

	var new_res: battle_group_data
	if want_preset:
		new_res = present_group_data.new()
		new_res.opponents = current_res.opponents.duplicate(true)
		new_res.rewards = current_res.rewards.duplicate(true)
	else:
		new_res = battle_group_data.new()
		new_res.opponents = current_res.opponents.duplicate(true)
		new_res.rewards = current_res.rewards.duplicate(true)

	current_res = new_res
	_update_preset_visibility(want_preset)

	_on_field_changed()


func _add_member_card(m_res: battle_group_member = null, target_container: VBoxContainer = null) -> void:
	if target_container == null:
		target_container = members_vbox

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 0.9)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Row 1: Character Search + Select Dropdown
	var char_row := HBoxContainer.new()
	var char_search := LineEdit.new()
	char_search.placeholder_text = "Search character..."
	char_search.clear_button_enabled = true
	char_search.custom_minimum_size = Vector2(160, 0)
	char_row.add_child(char_search)

	var char_select := OptionButton.new()
	char_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_row.add_child(char_select)

	var selected_character_ref: battle_character_base = m_res.character if (m_res and m_res.character) else null

	var populate_chars := func(filter: String = ""):
		char_select.clear()
		var filter_lower := filter.strip_edges().to_lower()
		var current_item_idx := 0
		var selected_idx_to_set := -1

		for c in loaded_characters:
			var matches_filter := (filter_lower == "" or c.name.to_lower().contains(filter_lower) or c == selected_character_ref)
			if matches_filter:
				char_select.add_item("👤 " + c.name, current_item_idx)
				char_select.set_item_metadata(current_item_idx, c)
				if c == selected_character_ref:
					selected_idx_to_set = current_item_idx
				current_item_idx += 1

		if selected_idx_to_set != -1:
			char_select.select(selected_idx_to_set)

	populate_chars.call("")

	char_select.item_selected.connect(func(idx):
		var chosen: battle_character_base = char_select.get_item_metadata(idx)
		if chosen:
			selected_character_ref = chosen
			if char_search.text != "":
				char_search.clear()
			else:
				_on_field_changed()
	)

	char_search.text_changed.connect(func(q): 
		populate_chars.call(q)
		_on_field_changed()
	)

	var del_btn := Button.new()
	del_btn.text = "Delete Member"
	del_btn.pressed.connect(func():
		card.queue_free()
		_on_field_changed()
	)
	char_row.add_child(del_btn)
	vbox.add_child(char_row)

	# Row 2: Level Sliders Section (Min above Max)
	var levels_vbox := VBoxContainer.new()
	levels_vbox.add_theme_constant_override("separation", 4)

	var level_lbl := Label.new()
	level_lbl.text = "Level Range: Lvl 1 - 1"
	levels_vbox.add_child(level_lbl)

	# 2a. Min Level Slider Row (Top)
	var min_row := HBoxContainer.new()
	var min_lbl := Label.new()
	min_lbl.text = "Min Lvl:"
	min_lbl.custom_minimum_size = Vector2(60, 0)
	min_row.add_child(min_lbl)

	var min_slider := HSlider.new()
	min_slider.min_value = 1
	min_slider.max_value = 50
	min_slider.value = 1
	min_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	min_row.add_child(min_slider)

	levels_vbox.add_child(min_row)

	# 2b. Max Level Slider Row (Bottom)
	var max_row := HBoxContainer.new()
	var max_lbl := Label.new()
	max_lbl.text = "Max Lvl:"
	max_lbl.custom_minimum_size = Vector2(60, 0)
	max_row.add_child(max_lbl)

	var max_slider := HSlider.new()
	max_slider.min_value = 1
	max_slider.max_value = 50
	max_slider.value = 1
	max_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	max_row.add_child(max_slider)

	var perma_check := CheckBox.new()
	perma_check.text = "PermaDeath"
	perma_check.toggled.connect(func(_t): _on_field_changed())
	max_row.add_child(perma_check)

	levels_vbox.add_child(max_row)
	vbox.add_child(levels_vbox)

	var update_level_readout := func():
		level_lbl.text = "Level Range: Lvl %d - %d" % [int(min_slider.value), int(max_slider.value)]

	# Min cannot go higher than Max (pushes Max up if needed)
	min_slider.value_changed.connect(func(val):
		if val > max_slider.value:
			max_slider.value = val
		update_level_readout.call()
		_on_field_changed()
	)

	# Max cannot go lower than Min (pulls Min down if needed)
	max_slider.value_changed.connect(func(val):
		if val < min_slider.value:
			min_slider.value = val
		update_level_readout.call()
		_on_field_changed()
	)

	# Row 3: Member Skills Section
	vbox.add_child(HSeparator.new())
	
	var skills_hdr := Label.new()
	skills_hdr.text = "Equipped Member Skills:"
	vbox.add_child(skills_hdr)

	var skills_container := VBoxContainer.new()
	card.set_meta("skills_container", skills_container)
	vbox.add_child(skills_container)

	var skill_search_row := HBoxContainer.new()
	var skill_search := LineEdit.new()
	skill_search.placeholder_text = "Search skill..."
	skill_search.clear_button_enabled = true
	skill_search.custom_minimum_size = Vector2(160, 0)
	skill_search_row.add_child(skill_search)

	var add_skill_select := OptionButton.new()
	add_skill_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_search_row.add_child(add_skill_select)

	var populate_skills := func(filter: String = ""):
		add_skill_select.clear()
		add_skill_select.add_item("+ Select Skill to Equip...", 0)

		var filter_lower := filter.strip_edges().to_lower()
		var count := 1
		for idx in range(loaded_skills.size()):
			var sk := loaded_skills[idx]
			if filter_lower == "" or sk.name.to_lower().contains(filter_lower):
				add_skill_select.add_item(sk.name, count)
				add_skill_select.set_item_metadata(count, sk)

				var elem_icon: Texture2D = _get_skill_element_texture(sk)
				if elem_icon:
					add_skill_select.set_item_icon(count, elem_icon)

				count += 1

	populate_skills.call("")
	skill_search.text_changed.connect(func(q): populate_skills.call(q))

	add_skill_select.item_selected.connect(func(idx):
		if idx > 0:
			var sk: rpg_skill = add_skill_select.get_item_metadata(idx)
			_add_skill_tag(skills_container, sk)
			add_skill_select.select(0)
			_on_field_changed()
	)
	vbox.add_child(skill_search_row)

	card.set_meta("char_select", char_select)
	card.set_meta("min_slider", min_slider)
	card.set_meta("max_slider", max_slider)
	card.set_meta("perma_check", perma_check)

	if m_res:
		min_slider.value = m_res.min_level
		max_slider.value = m_res.max_level
		update_level_readout.call()
		perma_check.button_pressed = m_res.perma_death

		for sk in m_res.skills:
			if sk: _add_skill_tag(skills_container, sk)

	target_container.add_child(card)


func _get_skill_element_texture(sk: rpg_skill) -> Texture2D:
	if not sk or not ("element" in sk) or not sk.element:
		return null
	var elem = sk.element
	if "icon" in elem and elem.icon is Texture2D:
		return elem.icon
	if "texture" in elem and elem.texture is Texture2D:
		return elem.texture
	return null


func _add_skill_tag(container: VBoxContainer, sk: rpg_skill) -> void:
	for c in container.get_children():
		if c.get_meta("skill_res") == sk:
			return

	var row := HBoxContainer.new()
	row.set_meta("skill_res", sk)

	var elem_tex := _get_skill_element_texture(sk)
	if elem_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = elem_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(18, 18)
		row.add_child(tex_rect)
	else:
		var icon_lbl := Label.new()
		icon_lbl.text = "⚡"
		row.add_child(icon_lbl)

	var l := Label.new()
	l.text = sk.name + " (Power: " + str(sk.power) + ")"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)

	var btn := Button.new()
	btn.text = "X"
	btn.pressed.connect(func():
		row.queue_free()
		_on_field_changed()
	)
	row.add_child(btn)
	container.add_child(row)


func _add_reward_card(r_res: battle_group_reward) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_meta("reward_instance", r_res)

	var flag_select := OptionButton.new()
	flag_select.add_item("No Flag Req", -1)
	for idx in range(loaded_flags.size()):
		flag_select.add_item("🚩 " + loaded_flags[idx].name, idx)
		flag_select.set_item_metadata(idx + 1, loaded_flags[idx])
	flag_select.item_selected.connect(func(_idx): _on_field_changed())
	row.add_child(flag_select)

	if r_res.flag_req:
		var f_idx := loaded_flags.find(r_res.flag_req)
		if f_idx != -1:
			flag_select.select(f_idx + 1)

	if r_res is reward_character:
		var char_select := OptionButton.new()
		for idx in range(loaded_characters.size()):
			char_select.add_item("👤 " + loaded_characters[idx].name, idx)
		char_select.item_selected.connect(func(_idx): _on_field_changed())
		row.add_child(char_select)
		row.set_meta("char_select", char_select)

		var lvl_spin := SpinBox.new()
		lvl_spin.min_value = 1
		lvl_spin.max_value = 50
		lvl_spin.prefix = "Join Lvl: "
		lvl_spin.value_changed.connect(func(_v): _on_field_changed())
		row.add_child(lvl_spin)
		row.set_meta("lvl_spin", lvl_spin)

		if r_res.character:
			var c_idx := loaded_characters.find(r_res.character)
			if c_idx != -1: char_select.select(c_idx)
		lvl_spin.value = r_res.level

	elif r_res is reward_change_flag:
		var target_flag_select := OptionButton.new()
		for idx in range(loaded_flags.size()):
			target_flag_select.add_item("🚩 Target: " + loaded_flags[idx].name, idx)
		target_flag_select.item_selected.connect(func(_idx): _on_field_changed())
		row.add_child(target_flag_select)
		row.set_meta("target_flag_select", target_flag_select)

		if r_res.flag_change:
			var tf_idx := loaded_flags.find(r_res.flag_change)
			if tf_idx != -1: target_flag_select.select(tf_idx)

	elif r_res is reward_extra_skill_count:
		var lbl := Label.new()
		lbl.text = "🎖️ Reward: +1 Extra Skill Slot Limit"
		row.add_child(lbl)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func():
		row.queue_free()
		_on_field_changed()
	)
	row.add_child(del_btn)

	row.set_meta("flag_select", flag_select)
	rewards_vbox.add_child(row)


func _load_all_reference_data() -> void:
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


func _load_group(path: String) -> void:
	current_path = path
	current_res = load(path)
	_load_all_reference_data()
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	status_label.text = "Editing: " + current_path.get_file()


func _populate_form() -> void:
	suppress_signals = true

	var is_preset := (current_res is present_group_data)

	if group_type_select:
		group_type_select.select(1 if is_preset else 0)

	_update_preset_visibility(is_preset)

	for c in members_vbox.get_children(): c.queue_free()
	for c in preset_vbox.get_children(): c.queue_free()
	for c in rewards_vbox.get_children(): c.queue_free()

	if current_res.opponents:
		for m in current_res.opponents:
			_add_member_card(m, members_vbox)

	if is_preset:
		var preset_res: present_group_data = current_res
		if preset_res.preset_members:
			for m in preset_res.preset_members:
				_add_member_card(m, preset_vbox)

	if current_res.rewards:
		for r in current_res.rewards:
			_add_reward_card(r)

	suppress_signals = false


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit or child is HSlider:
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
	status_label.text = "Unsaved changes to '" + current_path.get_file() + "'"


func _extract_members_from_container(container: VBoxContainer) -> Array[battle_group_member]:
	var list: Array[battle_group_member] = []
	for card in container.get_children():
		var char_select: OptionButton = card.get_meta("char_select")
		var min_slider: HSlider = card.get_meta("min_slider")
		var max_slider: HSlider = card.get_meta("max_slider")
		var perma_check: CheckBox = card.get_meta("perma_check")
		var skills_container: VBoxContainer = card.get_meta("skills_container")

		var m := battle_group_member.new()
		if char_select.selected >= 0:
			var selected_char: battle_character_base = char_select.get_item_metadata(char_select.selected)
			if selected_char: m.character = selected_char

		m.min_level = int(min_slider.value)
		m.max_level = int(max_slider.value)
		m.perma_death = perma_check.button_pressed

		var member_skills: Array[rpg_skill] = []
		for skill_row in skills_container.get_children():
			var sk: rpg_skill = skill_row.get_meta("skill_res")
			if sk: member_skills.append(sk)
		m.skills = member_skills

		list.append(m)
	return list


func _apply_ui_to_resource() -> void:
	current_res.opponents = _extract_members_from_container(members_vbox)

	if current_res is present_group_data:
		var preset_res: present_group_data = current_res
		preset_res.preset_members = _extract_members_from_container(preset_vbox)

	var rew_list: Array[battle_group_reward] = []
	for row in rewards_vbox.get_children():
		var r_inst: battle_group_reward = row.get_meta("reward_instance")
		var flag_select: OptionButton = row.get_meta("flag_select")

		if flag_select.selected > 0:
			r_inst.flag_req = flag_select.get_item_metadata(flag_select.selected)
		else:
			r_inst.flag_req = null

		if r_inst is reward_character:
			var char_select: OptionButton = row.get_meta("char_select")
			var lvl_spin: SpinBox = row.get_meta("lvl_spin")
			if char_select.selected >= 0 and char_select.selected < loaded_characters.size():
				r_inst.character = loaded_characters[char_select.selected]
			r_inst.level = int(lvl_spin.value)

		elif r_inst is reward_change_flag:
			var target_flag_select: OptionButton = row.get_meta("target_flag_select")
			if target_flag_select.selected >= 0 and target_flag_select.selected < loaded_flags.size():
				r_inst.flag_change = loaded_flags[target_flag_select.selected]

		rew_list.append(r_inst)

	current_res.rewards = rew_list


func _on_save_pressed() -> void:
	if not current_res:
		return

	_apply_ui_to_resource()

	var err := ResourceSaver.save(current_res, current_path)
	if err == OK:
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "Saved '" + current_path.get_file() + "' to disk."
		_filter_and_populate_groups()
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
	status_label.text = "Reverted '" + current_path.get_file() + "'"
