# res://addons/behaviour_editor/behaviour_editor.gd
@tool
extends Control

const BEHAVIOUR_DIR := "res://data/behaviours/"
const SKILL_DIR := "res://data/skills"
const ELEMENT_DIR := "res://data/elements"
const STATUS_DIR := "res://data/status_effects"

@onready var folder_select: OptionButton = %FolderSelect
@onready var search_bar: LineEdit = %SearchBar
@onready var refresh_button: Button = %RefreshButton
@onready var new_behaviour_button: Button = %NewBehaviourButton
@onready var behaviour_list: ItemList = %BehaviourList

@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

# Rename UI Controls
var rename_button: Button
var rename_dialog: ConfirmationDialog
var rename_input: LineEdit

var current_path: String = ""
var current_res: battle_chara_behaviour = null

var loaded_folders: Array[String] = []
var loaded_skills: Array[rpg_skill] = []
var loaded_elements: Array[element] = []
var loaded_status_effects: Array[status_effect] = []

# Form UI controls
var priority_spin: SpinBox
var percentage_slider: HSlider
var percentage_lbl: Label
var conditions_vbox: VBoxContainer

var suppress_signals: bool = false
var dirty: bool = false


func _ready() -> void:
	if not is_instance_valid(behaviour_list):
		return

	_setup_rename_ui()

	refresh_button.pressed.connect(_refresh_all)
	search_bar.text_changed.connect(func(_q): _filter_and_populate_list())
	folder_select.item_selected.connect(func(_idx): _filter_and_populate_list())
	behaviour_list.item_selected.connect(_on_behaviour_selected)

	new_behaviour_button.pressed.connect(_on_new_behaviour_pressed)
	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	_build_form()
	_set_form_enabled(false)
	call_deferred("_refresh_all")


func _setup_rename_ui() -> void:
	var toolbar: HBoxContainer = %SaveButton.get_parent()

	rename_button = Button.new()
	rename_button.text = "Rename File"
	rename_button.disabled = true
	rename_button.pressed.connect(_on_rename_pressed)
	toolbar.add_child(rename_button)
	toolbar.move_child(rename_button, 1)

	# Build Confirmation Dialog for renaming
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Behaviour Resource"
	rename_dialog.size = Vector2i(350, 100)

	var vbox := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Enter new file name:"
	vbox.add_child(lbl)

	rename_input = LineEdit.new()
	rename_input.placeholder_text = "new_behaviour_name"
	vbox.add_child(rename_input)

	rename_dialog.add_child(vbox)
	rename_dialog.confirmed.connect(_confirm_rename)
	add_child(rename_dialog)


func _on_rename_pressed() -> void:
	if current_path == "":
		return
	var current_name := current_path.get_file().get_basename()
	rename_input.text = current_name
	rename_dialog.popup_centered()
	rename_input.select_all()
	rename_input.grab_focus()


func _confirm_rename() -> void:
	var new_name := rename_input.text.strip_edges()
	if new_name == "" or not current_res:
		return

	if not new_name.ends_with(".tres") and not new_name.ends_with(".res"):
		new_name += ".tres"

	var parent_dir := current_path.get_base_dir()
	var new_full_path := parent_dir.path_join(new_name)

	if new_full_path == current_path:
		return

	if FileAccess.file_exists(new_full_path):
		status_label.text = "Rename failed: File '%s' already exists!" % new_name
		return

	# Perform disk rename
	var err := DirAccess.rename_absolute(current_path, new_full_path)
	if err == OK:
		current_path = new_full_path
		status_label.text = "Renamed file to: " + new_name
		_filter_and_populate_list()
	else:
		status_label.text = "Rename failed (error %d)" % err


func _refresh_all() -> void:
	_load_folders()
	_load_reference_resources()
	_filter_and_populate_list()


func _load_folders() -> void:
	loaded_folders.clear()
	folder_select.clear()

	folder_select.add_item("📁 All Folders", 0)
	folder_select.set_item_metadata(0, BEHAVIOUR_DIR)

	_scan_folders_recursive(BEHAVIOUR_DIR)

	for idx in range(loaded_folders.size()):
		var sub_path := loaded_folders[idx]
		var rel_path := sub_path.replace(BEHAVIOUR_DIR, "")
		if rel_path.begins_with("/"):
			rel_path = rel_path.substr(1)
		folder_select.add_item("📂 " + rel_path, idx + 1)
		folder_select.set_item_metadata(idx + 1, sub_path)


func _scan_folders_recursive(dir_path: String) -> void:
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
				loaded_folders.append(full_path)
				_scan_folders_recursive(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_reference_resources() -> void:
	loaded_skills.clear()
	for p in _find_resources_recursive(SKILL_DIR):
		var res = load(p)
		if res is rpg_skill:
			loaded_skills.append(res)

	loaded_elements.clear()
	for p in _find_resources_recursive(ELEMENT_DIR):
		var res = load(p)
		if res is element:
			loaded_elements.append(res)

	loaded_status_effects.clear()
	for p in _find_resources_recursive(STATUS_DIR):
		var res = load(p)
		if res is status_effect:
			loaded_status_effects.append(res)


func _filter_and_populate_list() -> void:
	behaviour_list.clear()

	var selected_idx := folder_select.selected
	var target_dir: String = folder_select.get_item_metadata(selected_idx) if selected_idx >= 0 else BEHAVIOUR_DIR
	var search_filter := search_bar.text.strip_edges().to_lower()

	var paths := _find_resources_recursive(target_dir)
	paths.sort()

	for file_path in paths:
		var res = load(file_path)
		if res is battle_chara_behaviour:
			var display_name := file_path.get_file().get_basename()
			var matches_search := (search_filter == "" or display_name.to_lower().contains(search_filter))

			if matches_search:
				var item_idx := behaviour_list.add_item(display_name)
				behaviour_list.set_item_metadata(item_idx, file_path)

				if file_path == current_path:
					behaviour_list.select(item_idx)


func _on_behaviour_selected(index: int) -> void:
	var path: String = behaviour_list.get_item_metadata(index)
	if path != "":
		_load_behaviour(path)


func _on_new_behaviour_pressed() -> void:
	var selected_idx := folder_select.selected
	var parent_dir: String = folder_select.get_item_metadata(selected_idx) if selected_idx >= 0 else BEHAVIOUR_DIR

	var base_filename := "new_chara_behaviour"
	var file_path := parent_dir.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = parent_dir.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_res := battle_chara_behaviour.new()
	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		_refresh_all()
		_load_behaviour(file_path)
		status_label.text = "Created new chara behaviour at: " + file_path
	else:
		status_label.text = "Failed to create file (error %d)" % err


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

	# ---- 1. Behaviour Settings ----
	form_root.add_child(_section_header("Behaviour Properties"))

	# Priority Integer SpinBox
	var prio_row := HBoxContainer.new()
	var prio_lbl := Label.new()
	prio_lbl.text = "Priority (Higher = Priority):"
	prio_lbl.custom_minimum_size = Vector2(200, 0)
	prio_row.add_child(prio_lbl)

	priority_spin = SpinBox.new()
	priority_spin.min_value = -99
	priority_spin.max_value = 99
	priority_spin.value = 0
	priority_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priority_spin.value_changed.connect(func(_v): _on_field_changed())
	prio_row.add_child(priority_spin)
	form_root.add_child(prio_row)

	# Percentage Slider
	var perc_row := HBoxContainer.new()
	percentage_lbl = Label.new()
	percentage_lbl.text = "Percentage Weight: 100%"
	percentage_lbl.custom_minimum_size = Vector2(200, 0)
	perc_row.add_child(percentage_lbl)

	percentage_slider = HSlider.new()
	percentage_slider.min_value = 0.0
	percentage_slider.max_value = 1.0
	percentage_slider.step = 0.01
	percentage_slider.value = 1.0
	percentage_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	percentage_slider.value_changed.connect(func(v):
		percentage_lbl.text = "Percentage Weight: %d%%" % int(v * 100)
		_on_field_changed()
	)
	perc_row.add_child(percentage_slider)
	form_root.add_child(perc_row)

	form_root.add_child(HSeparator.new())

	# ---- 2. Conditions List Section ----
	form_root.add_child(_section_header("Conditions List (condiitons)"))

	conditions_vbox = VBoxContainer.new()
	conditions_vbox.add_theme_constant_override("separation", 10)
	form_root.add_child(conditions_vbox)

	var add_cond_btn := Button.new()
	add_cond_btn.text = "+ Add Condition Rule"
	add_cond_btn.pressed.connect(func():
		_add_condition_card(battle_character_behaviour.new())
		_on_field_changed()
	)
	form_root.add_child(add_cond_btn)


func _add_condition_card(cond_res: battle_character_behaviour = null) -> void:
	if not cond_res:
		cond_res = battle_character_behaviour.new()

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.18, 0.9)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var desc_row := HBoxContainer.new()
	var desc_lbl := Label.new()
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(desc_lbl)

	var del_btn := Button.new()
	del_btn.text = "Delete Rule"
	del_btn.pressed.connect(func():
		card.queue_free()
		_on_field_changed()
	)
	desc_row.add_child(del_btn)
	vbox.add_child(desc_row)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)

	var sub_lbl := Label.new()
	sub_lbl.text = "Subject:"
	row1.add_child(sub_lbl)

	var sub_select := OptionButton.new()
	for key in battle_character_behaviour.SUBJECT.keys():
		sub_select.add_item(key)
	sub_select.select(cond_res.subject)
	sub_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sub_select)

	var comp_lbl := Label.new()
	comp_lbl.text = "Compare:"
	row1.add_child(comp_lbl)

	var comp_select := OptionButton.new()
	for key in battle_character_behaviour.NUMBER_COMP.keys():
		comp_select.add_item(key)
	comp_select.select(cond_res.compare)
	comp_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(comp_select)

	vbox.add_child(row1)

	var cond_type_row := HBoxContainer.new()
	cond_type_row.add_theme_constant_override("separation", 8)

	var target_cond_lbl := Label.new()
	target_cond_lbl.text = "Target Cond:"
	cond_type_row.add_child(target_cond_lbl)

	var target_cond_select := OptionButton.new()
	for key in battle_character_behaviour.TARGET_CONDITION.keys():
		target_cond_select.add_item(key)
	target_cond_select.select(cond_res.target_condition)
	target_cond_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_type_row.add_child(target_cond_select)

	var skill_cond_lbl := Label.new()
	skill_cond_lbl.text = "Skill Cond:"
	cond_type_row.add_child(skill_cond_lbl)

	var skill_cond_select := OptionButton.new()
	for key in battle_character_behaviour.SKILL_CONDITION.keys():
		skill_cond_select.add_item(key)
	skill_cond_select.select(cond_res.skill_condition)
	skill_cond_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_type_row.add_child(skill_cond_select)

	vbox.add_child(cond_type_row)

	var val_row := HBoxContainer.new()
	val_row.add_theme_constant_override("separation", 8)

	var perc_sub_row := HBoxContainer.new()
	var perc_lbl := Label.new()
	perc_lbl.text = "HP/Stam %:"
	perc_sub_row.add_child(perc_lbl)
	var perc_spin := SpinBox.new()
	perc_spin.min_value = 0.0
	perc_spin.max_value = 1.0
	perc_spin.step = 0.01
	perc_spin.value = cond_res.percentage
	perc_sub_row.add_child(perc_spin)
	val_row.add_child(perc_sub_row)

	var elem_sub_row := HBoxContainer.new()
	var elem_lbl := Label.new()
	elem_lbl.text = "Affinity:"
	elem_sub_row.add_child(elem_lbl)
	var elem_spin := SpinBox.new()
	elem_spin.min_value = -2.0
	elem_spin.max_value = 2.0
	elem_spin.step = 0.01
	elem_spin.value = cond_res.elemental
	elem_sub_row.add_child(elem_spin)
	val_row.add_child(elem_sub_row)

	var num_sub_row := HBoxContainer.new()
	var num_lbl := Label.new()
	num_lbl.text = "Exact Num:"
	num_sub_row.add_child(num_lbl)
	var num_spin := SpinBox.new()
	num_spin.min_value = 0
	num_spin.max_value = 999
	num_spin.value = cond_res.exact_number
	num_sub_row.add_child(num_spin)
	val_row.add_child(num_sub_row)

	var chance_sub_row := HBoxContainer.new()
	var chance_lbl := Label.new()
	chance_lbl.text = "Chance:"
	chance_sub_row.add_child(chance_lbl)
	var chance_spin := SpinBox.new()
	chance_spin.min_value = 0.0
	chance_spin.max_value = 1.0
	chance_spin.step = 0.05
	chance_spin.value = cond_res.execution_chance
	chance_sub_row.add_child(chance_spin)
	val_row.add_child(chance_sub_row)

	vbox.add_child(val_row)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)

	var skill_select := OptionButton.new()
	skill_select.add_item("Specific Skill: None", 0)
	for i in range(loaded_skills.size()):
		skill_select.add_item("⚔️ " + loaded_skills[i].name, i + 1)
		skill_select.set_item_metadata(i + 1, loaded_skills[i])
		if loaded_skills[i] == cond_res.specific_skill:
			skill_select.select(i + 1)
	skill_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(skill_select)

	var elem_select := OptionButton.new()
	elem_select.add_item("Specific Element: None", 0)
	for i in range(loaded_elements.size()):
		elem_select.add_item("⚡ " + loaded_elements[i].name, i + 1)
		elem_select.set_item_metadata(i + 1, loaded_elements[i])
		if loaded_elements[i] == cond_res.specific_element:
			elem_select.select(i + 1)
	elem_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(elem_select)

	var status_select := OptionButton.new()
	status_select.add_item("Specific Status: None", 0)
	for i in range(loaded_status_effects.size()):
		status_select.add_item("🧪 " + loaded_status_effects[i].name, i + 1)
		status_select.set_item_metadata(i + 1, loaded_status_effects[i])
		if loaded_status_effects[i] == cond_res.specific_status:
			status_select.select(i + 1)
	status_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(status_select)

	vbox.add_child(res_row)

	var update_card_state := func():
		cond_res.subject = sub_select.selected as battle_character_behaviour.SUBJECT
		cond_res.compare = comp_select.selected as battle_character_behaviour.NUMBER_COMP
		cond_res.target_condition = target_cond_select.selected as battle_character_behaviour.TARGET_CONDITION
		cond_res.skill_condition = skill_cond_select.selected as battle_character_behaviour.SKILL_CONDITION

		cond_res.percentage = perc_spin.value
		cond_res.elemental = elem_spin.value
		cond_res.exact_number = int(num_spin.value)
		cond_res.execution_chance = chance_spin.value

		cond_res.specific_skill = skill_select.get_item_metadata(skill_select.selected) if skill_select.selected > 0 else null
		cond_res.specific_element = elem_select.get_item_metadata(elem_select.selected) if elem_select.selected > 0 else null
		cond_res.specific_status = status_select.get_item_metadata(status_select.selected) if status_select.selected > 0 else null

		var sb := cond_res.subject
		target_cond_lbl.visible = (sb == battle_character_behaviour.SUBJECT.TARGET or sb == battle_character_behaviour.SUBJECT.TARGET_INVERSE)
		target_cond_select.visible = target_cond_lbl.visible
		skill_cond_lbl.visible = (sb == battle_character_behaviour.SUBJECT.SKILL)
		skill_cond_select.visible = skill_cond_lbl.visible

		perc_sub_row.visible = false
		elem_sub_row.visible = false
		num_sub_row.visible = false
		skill_select.visible = false
		elem_select.visible = false
		status_select.visible = false

		if sb == battle_character_behaviour.SUBJECT.TARGET or sb == battle_character_behaviour.SUBJECT.TARGET_INVERSE:
			match cond_res.target_condition:
				battle_character_behaviour.TARGET_CONDITION.HEALTH, battle_character_behaviour.TARGET_CONDITION.STAMINA:
					perc_sub_row.visible = true
				battle_character_behaviour.TARGET_CONDITION.STATUS_EFFECT:
					status_select.visible = true
				battle_character_behaviour.TARGET_CONDITION.ELEMENTAL_AFFINITY:
					elem_sub_row.visible = true
					elem_select.visible = true
				battle_character_behaviour.TARGET_CONDITION.STATUS_MODIFY_AFFINITY:
					elem_sub_row.visible = true

		elif sb == battle_character_behaviour.SUBJECT.SKILL:
			match cond_res.skill_condition:
				battle_character_behaviour.SKILL_CONDITION.SPECIFIC:
					skill_select.visible = true
				battle_character_behaviour.SKILL_CONDITION.ELEMENT:
					elem_select.visible = true
				battle_character_behaviour.SKILL_CONDITION.POWER:
					num_sub_row.visible = true
				battle_character_behaviour.SKILL_CONDITION.STATUS:
					status_select.visible = true

		elif sb == battle_character_behaviour.SUBJECT.TURN or sb == battle_character_behaviour.SUBJECT.ROUND:
			num_sub_row.visible = true

		if cond_res.has_method("get_description"):
			desc_lbl.text = "Rule: " + cond_res.get_description()
		else:
			desc_lbl.text = "Rule: " + battle_character_behaviour.SUBJECT.keys()[cond_res.subject]

	sub_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())
	comp_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())
	target_cond_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())
	skill_cond_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())

	perc_spin.value_changed.connect(func(_v): update_card_state.call(); _on_field_changed())
	elem_spin.value_changed.connect(func(_v): update_card_state.call(); _on_field_changed())
	num_spin.value_changed.connect(func(_v): update_card_state.call(); _on_field_changed())
	chance_spin.value_changed.connect(func(_v): update_card_state.call(); _on_field_changed())

	skill_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())
	elem_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())
	status_select.item_selected.connect(func(_i): update_card_state.call(); _on_field_changed())

	card.set_meta("cond_instance", cond_res)
	update_card_state.call()

	conditions_vbox.add_child(card)


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


func _load_behaviour(path: String) -> void:
	current_path = path
	current_res = load(path)
	_load_reference_resources()
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	rename_button.disabled = false
	status_label.text = "Editing: " + current_path.get_file()


func _populate_form() -> void:
	if not current_res:
		return

	suppress_signals = true

	priority_spin.value = current_res.priority if "priority" in current_res else 0
	percentage_slider.value = current_res.percentage
	percentage_lbl.text = "Percentage Weight: %d%%" % int(current_res.percentage * 100)

	for c in conditions_vbox.get_children():
		c.queue_free()

	if current_res.condiitons:
		for cond in current_res.condiitons:
			if cond:
				_add_condition_card(cond)

	suppress_signals = false


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	if is_instance_valid(rename_button):
		rename_button.disabled = not enabled
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit or child is HSlider:
			child.editable = enabled
		elif child is Button or child is CheckBox or child is OptionButton or child is MenuButton:
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


func _apply_ui_to_resource() -> void:
	if not current_res:
		return

	if "priority" in current_res:
		current_res.priority = int(priority_spin.value)
	current_res.percentage = percentage_slider.value

	var cond_list: Array[battle_character_behaviour] = []
	for card in conditions_vbox.get_children():
		var cond_res: battle_character_behaviour = card.get_meta("cond_instance")
		if cond_res:
			cond_list.append(cond_res)

	current_res.condiitons = cond_list


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
		_filter_and_populate_list()
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
