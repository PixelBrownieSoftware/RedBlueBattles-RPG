# res://addons/status_effect_editor/status_effect_editor.gd
@tool
extends Control

const STATUS_DIR := "res://data/status_effects"
const ELEMENT_DIR := "res://data/elements"
const STAT_ICON_DIR := "res://sprites/GUI/stats/"
const SCRIPT_DIR := "res://src/scripts/status_effects/" # Adjust path if custom status scripts reside elsewhere

var tree: Tree
var refresh_button: Button
var new_status_button: Button
var save_button: Button
var revert_button: Button
var status_label: Label
var form_root: VBoxContainer

# File Management UI Controls
var rename_button: Button
var delete_button: Button
var rename_dialog: ConfirmationDialog
var rename_input: LineEdit
var delete_confirm_dialog: ConfirmationDialog

# Type Selector Controls
var class_type_select: OptionButton
var dynamic_fields_vbox: VBoxContainer
var dynamic_controls: Dictionary = {}

var current_path: String = ""
var current_res: status_effect = null
var elements: Array = []
var loaded_status_scripts: Array[Dictionary] = [] # Array of { "display_name": String, "script": Script }

# Form Controls
var name_edit: LineEdit
var duration_edit: SpinBox

var round_start_check: CheckBox
var after_action_check: CheckBox
var turn_start_check: CheckBox
var contribute_mult_check: CheckBox

var icon_preview: TextureRect
var file_dialog: EditorFileDialog

var stat_change_edits: Dictionary = {}
var affinity_display: ElementalAffinityDisplay

var dirty: bool = false
var suppress_signals: bool = false


func _ready() -> void:
	_bind_ui_nodes()
	_setup_file_dialog()
	_setup_file_management_ui()

	if is_instance_valid(refresh_button):
		refresh_button.pressed.connect(_populate_tree)
	if is_instance_valid(new_status_button):
		new_status_button.pressed.connect(_on_new_status_pressed)
	if is_instance_valid(tree):
		tree.item_selected.connect(_on_tree_item_selected)
	if is_instance_valid(save_button):
		save_button.pressed.connect(_on_save_pressed)
	if is_instance_valid(revert_button):
		revert_button.pressed.connect(_on_revert_pressed)

	if is_instance_valid(form_root):
		for child in form_root.get_children():
			child.queue_free()

	_load_elements()
	_load_status_scripts()
	_build_form()
	_set_form_enabled(false)
	call_deferred("_populate_tree")


func _bind_ui_nodes() -> void:
	tree = _find_control_node("Tree") as Tree
	refresh_button = _find_control_node("RefreshButton") as Button
	new_status_button = _find_control_node("NewStatusButton") as Button
	save_button = _find_control_node("SaveButton") as Button
	revert_button = _find_control_node("RevertButton") as Button
	status_label = _find_control_node("StatusLabel") as Label
	form_root = _find_control_node("FormRoot") as VBoxContainer


func _setup_file_management_ui() -> void:
	var toolbar: HBoxContainer = null
	if is_instance_valid(save_button):
		toolbar = save_button.get_parent() as HBoxContainer

	if toolbar:
		rename_button = Button.new()
		rename_button.text = "Rename File"
		rename_button.disabled = true
		rename_button.pressed.connect(_on_rename_pressed)
		toolbar.add_child(rename_button)

		delete_button = Button.new()
		delete_button.text = "Delete File"
		delete_button.disabled = true
		delete_button.pressed.connect(_on_delete_pressed)
		toolbar.add_child(delete_button)

	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Status Resource"
	rename_dialog.size = Vector2i(350, 100)

	var vbox := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Enter new file name:"
	vbox.add_child(lbl)

	rename_input = LineEdit.new()
	rename_input.placeholder_text = "new_status_effect"
	vbox.add_child(rename_input)

	rename_dialog.add_child(vbox)
	rename_dialog.confirmed.connect(_confirm_rename)
	add_child(rename_dialog)

	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "Delete Status Resource?"
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete this status effect file permanently?"
	delete_confirm_dialog.confirmed.connect(_confirm_delete)
	add_child(delete_confirm_dialog)


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
		if is_instance_valid(status_label):
			status_label.text = "Rename failed: File '%s' already exists!" % new_name
		return

	var old_path := current_path
	var err := DirAccess.rename_absolute(old_path, new_full_path)
	if err == OK:
		current_path = new_full_path
		if is_instance_valid(status_label):
			status_label.text = "Renamed file to: " + new_name
		_populate_tree()
	else:
		if is_instance_valid(status_label):
			status_label.text = "Rename failed (error %d)" % err


func _on_delete_pressed() -> void:
	if current_path == "":
		return
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?" % current_path.get_file()
	delete_confirm_dialog.popup_centered()


func _confirm_delete() -> void:
	if current_path == "":
		return

	var file_to_delete := current_path
	var err := DirAccess.remove_absolute(file_to_delete)
	if err == OK:
		if is_instance_valid(status_label):
			status_label.text = "Deleted status effect: " + file_to_delete.get_file()
		current_path = ""
		current_res = null
		_set_form_enabled(false)
		_populate_tree()
	else:
		if is_instance_valid(status_label):
			status_label.text = "Failed to delete file (error %d)" % err


func _find_control_node(node_name: String) -> Node:
	if has_node("%" + node_name):
		return get_node("%" + node_name)
	return find_child(node_name, true, false)


func _ensure_directories_exist() -> void:
	for dir_path in [STATUS_DIR, ELEMENT_DIR]:
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)


func _setup_file_dialog() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.png, *.svg, *.jpg, *.jpeg, *.tres, *.res; Texture Resources")
	file_dialog.file_selected.connect(_on_icon_file_selected)
	add_child(file_dialog)


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
		var tr := TextureRect.new()
		tr.texture = icon_texture
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(20, 20)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)

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
	s.value_changed.connect(func(_v): _on_field_changed())
	return s


func _make_float_spin(min_v: float, max_v: float, step: float = 0.01) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value_changed.connect(func(_v): _on_field_changed())
	return s


func _load_gui_icon(dir_path: String, prefix: String, item_name: String) -> Texture2D:
	var clean_name := item_name.to_lower().strip_edges()
	var full_path := dir_path.path_join(prefix + clean_name + ".png")
	if ResourceLoader.exists(full_path):
		return load(full_path) as Texture2D
	return null


func _load_elements() -> void:
	elements.clear()
	var paths := _find_resources_recursive(ELEMENT_DIR)
	for path in paths:
		var res = load(path)
		if res and ("name" in res or res is element):
			elements.append(res)
	elements.sort_custom(func(a, b): 
		var a_name: String = a.name if "name" in a else ""
		var b_name: String = b.name if "name" in b else ""
		return a_name < b_name
	)


func _load_status_scripts() -> void:
	loaded_status_scripts.clear()

	# Register core status types
	loaded_status_scripts.append({"display_name": "Base Status Effect (status_effect)", "script": status_effect})
	loaded_status_scripts.append({"display_name": "Damage Over Time (status_damage)", "script": status_damage})
	loaded_status_scripts.append({"display_name": "Stamina Drain/Boost (status_stamina)", "script": status_stamina})

	if DirAccess.dir_exists_absolute(SCRIPT_DIR):
		var paths := _find_resources_recursive(SCRIPT_DIR, [".gd"])
		paths.sort()
		for path in paths:
			var scr = load(path) as Script
			if scr and scr.inherits("status_effect"):
				var script_name := path.get_file().get_basename()
				var global_name := scr.get_global_name()
				var display_name: String = (global_name if global_name != "" else script_name) + " (" + script_name + ".gd)"
				
				var already_exists := false
				for item in loaded_status_scripts:
					if item.script == scr:
						already_exists = true
						break
				if not already_exists:
					loaded_status_scripts.append({"display_name": display_name, "script": scr})


func _build_form() -> void:
	if not is_instance_valid(form_root):
		return

	# ---- Class Type Selector ----
	form_root.add_child(_section_header("Status Type Class"))

	class_type_select = OptionButton.new()
	class_type_select.clear()
	for idx in range(loaded_status_scripts.size()):
		var info := loaded_status_scripts[idx]
		class_type_select.add_item("📜 " + info.display_name, idx)
		class_type_select.set_item_metadata(idx, info)

	class_type_select.item_selected.connect(_on_class_type_changed)
	form_root.add_child(_labeled_row("Status Type", class_type_select))

	form_root.add_child(_hsep())

	# ---- Identity & Duration ----
	form_root.add_child(_section_header("Identity & Duration"))

	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Effect Name", name_edit))

	duration_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Turn Duration", duration_edit))

	form_root.add_child(_hsep())

	# ---- Dynamic Custom Fields Container ----
	dynamic_fields_vbox = VBoxContainer.new()
	dynamic_fields_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(dynamic_fields_vbox)

	# ---- Trigger Flags ----
	form_root.add_child(_section_header("Trigger Conditions & Flags"))

	round_start_check = CheckBox.new()
	round_start_check.text = "Decrement duration on Round Start"
	round_start_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Round Start Trigger", round_start_check))

	after_action_check = CheckBox.new()
	after_action_check.text = "Decrement duration After Action"
	after_action_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("After Action Trigger", after_action_check))

	turn_start_check = CheckBox.new()
	turn_start_check.text = "Decrement duration on Turn Start"
	turn_start_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Turn Start Trigger", turn_start_check))

	contribute_mult_check = CheckBox.new()
	contribute_mult_check.text = "Contribute Multiplier Flag"
	contribute_mult_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Contribute Multiplier", contribute_mult_check))

	form_root.add_child(_hsep())

	# ---- Visual Icon ----
	form_root.add_child(_section_header("Visual Icon"))

	var icon_hbox := HBoxContainer.new()
	icon_hbox.add_theme_constant_override("separation", 8)

	icon_preview = TextureRect.new()
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.custom_minimum_size = Vector2(32, 32)
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_hbox.add_child(icon_preview)

	var browse_btn := Button.new()
	browse_btn.text = "Choose Icon..."
	browse_btn.pressed.connect(func(): file_dialog.popup_file_dialog())
	icon_hbox.add_child(browse_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func(): _set_icon_texture(null))
	icon_hbox.add_child(clear_btn)

	form_root.add_child(_labeled_row("Status Icon", icon_hbox))

	form_root.add_child(_hsep())

	# ---- Stat Changes (rpg_stats) ----
	form_root.add_child(_section_header("Stat Modifiers (rpg_stats)"))
	var stats_list := ["strength", "vitality", "dexterity", "magic_pow", "agility", "luck"]
	for stat_name in stats_list:
		var icon: Texture2D = _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
		var s := _make_int_spin(-999, 999, 1)
		stat_change_edits[stat_name] = s
		form_root.add_child(_labeled_row(stat_name.capitalize() + " Change", s, icon))

	form_root.add_child(_hsep())

	# ---- Elemental Affinity Changes ----
	form_root.add_child(_section_header("Elemental Affinity Modifiers (-1 to 2 Sliders)"))
	affinity_display = ElementalAffinityDisplay.new()
	affinity_display.upper_lower_limit = Vector2(-1.0, 2.0)
	affinity_display.default_value = 0.0
	affinity_display.custom_minimum_size = Vector2(0, 100)
	affinity_display.affinity_changed.connect(func(_el, _val): _on_field_changed())
	form_root.add_child(affinity_display)


func _on_class_type_changed(idx: int) -> void:
	if not current_res or idx < 0 or idx >= loaded_status_scripts.size():
		return

	var info: Dictionary = loaded_status_scripts[idx]
	var target_script: Script = info.script

	if current_res.get_script() == target_script:
		return

	var new_inst: status_effect = target_script.new() if target_script else status_effect.new()

	if "name" in current_res and "name" in new_inst: new_inst.name = current_res.name
	if "turn_duration" in current_res and "turn_duration" in new_inst: new_inst.turn_duration = current_res.turn_duration
	if "round_start" in current_res and "round_start" in new_inst: new_inst.round_start = current_res.round_start
	if "after_action" in current_res and "after_action" in new_inst: new_inst.after_action = current_res.after_action
	if "turn_start" in current_res and "turn_start" in new_inst: new_inst.turn_start = current_res.turn_start
	if "contribute_multipler" in current_res and "contribute_multipler" in new_inst: new_inst.contribute_multipler = current_res.contribute_multipler
	if "icon" in current_res and "icon" in new_inst: new_inst.icon = current_res.icon
	if "stat_changes" in current_res and "stat_changes" in new_inst: new_inst.stat_changes = current_res.stat_changes
	if "elemental_affinity_change" in current_res and "elemental_affinity_change" in new_inst: new_inst.elemental_affinity_change = current_res.elemental_affinity_change

	current_res = new_inst
	_populate_form()
	_on_field_changed()


func _build_dynamic_fields_for_custom_type() -> void:
	for child in dynamic_fields_vbox.get_children():
		child.queue_free()

	dynamic_controls.clear()

	if not current_res:
		return

	var base_properties := ["script", "Built-in Script", "name", "turn_duration", "round_start", 
		"after_action", "turn_start", "contribute_multipler", "icon", "stat_changes", "elemental_affinity_change", "effects_to_remove"]

	var props := current_res.get_property_list()
	var custom_props: Array[Dictionary] = []

	for p in props:
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or p.usage & PROPERTY_USAGE_EDITOR:
			if not base_properties.has(p.name):
				custom_props.append(p)

	if custom_props.is_empty():
		return

	var current_scr = current_res.get_script()
	var scr_name: String = current_scr.get_global_name() if (current_scr and current_scr.get_global_name() != "") else (current_scr.resource_path.get_file() if current_scr else "Subclass")
	dynamic_fields_vbox.add_child(_section_header("Custom Status Properties (" + scr_name + ")"))

	for p in custom_props:
		var p_name: String = p.name
		var p_type: int = p.type
		var val = current_res.get(p_name)

		match p_type:
			TYPE_BOOL:
				var cb := CheckBox.new()
				cb.button_pressed = bool(val)
				cb.toggled.connect(func(_t): _on_field_changed())
				dynamic_controls[p_name] = cb
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), cb))

			TYPE_INT:
				var spin := _make_int_spin(-99999, 99999, 1)
				spin.value = int(val) if val != null else 0
				dynamic_controls[p_name] = spin
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), spin))

			TYPE_FLOAT:
				var spin := _make_float_spin(-99999.0, 99999.0, 0.01)
				spin.value = float(val) if val != null else 0.0
				dynamic_controls[p_name] = spin
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), spin))

			TYPE_STRING:
				var le := LineEdit.new()
				le.text = str(val) if val != null else ""
				le.text_changed.connect(func(_t): _on_field_changed())
				dynamic_controls[p_name] = le
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), le))


func _on_new_status_pressed() -> void:
	_ensure_directories_exist()

	var base_filename := "new_status_effect"
	var file_path := STATUS_DIR.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = STATUS_DIR.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_res := status_effect.new()
	new_res.name = "New Status Effect " + str(count)

	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		_populate_tree()
		_load_status_effect(file_path)
		if is_instance_valid(status_label):
			status_label.text = "Created status effect at: " + file_path
	else:
		if is_instance_valid(status_label):
			status_label.text = "Failed to create status effect (error %d)" % err


func _on_icon_file_selected(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			_set_icon_texture(tex)


func _set_icon_texture(tex: Texture2D) -> void:
	if not current_res:
		return
	current_res.icon = tex
	icon_preview.texture = tex
	_on_field_changed()


func _set_form_enabled(enabled: bool) -> void:
	if is_instance_valid(form_root):
		form_root.modulate.a = 1.0 if enabled else 0.5
		_set_container_editable(form_root, enabled)
	if is_instance_valid(affinity_display):
		affinity_display.is_editable = enabled
	if is_instance_valid(rename_button):
		rename_button.disabled = not enabled
	if is_instance_valid(delete_button):
		delete_button.disabled = not enabled


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child == affinity_display:
			continue
		if child is SpinBox or child is LineEdit:
			child.editable = enabled
		elif child is Button or child is ColorPickerButton or child is CheckBox or child is OptionButton:
			child.disabled = not enabled
		else:
			_set_container_editable(child, enabled)


func _find_resources_recursive(path: String, valid_extensions: Array[String] = [".tres", ".res"]) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				var full_path := path.path_join(file_name)
				if dir.current_is_dir():
					results.append_array(_find_resources_recursive(full_path, valid_extensions))
				else:
					for ext in valid_extensions:
						if file_name.ends_with(ext):
							results.append(full_path)
							break
			file_name = dir.get_next()
		dir.list_dir_end()
	return results


func _populate_tree() -> void:
	if not is_instance_valid(tree):
		return
	tree.clear()
	var root := tree.create_item()

	_ensure_directories_exist()

	var paths := _find_resources_recursive(STATUS_DIR)
	paths.sort()

	for epath in paths:
		var res = load(epath)
		if res is status_effect or (res and "turn_duration" in res):
			var item := tree.create_item(root)
			var display_name: String = res.name if ("name" in res and res.name != "") else epath.get_file()
			item.set_text(0, display_name)
			item.set_metadata(0, epath)

			# Display icon alongside status effect name if it exists
			if "icon" in res and res.icon is Texture2D:
				item.set_icon(0, res.icon)
				item.set_icon_max_width(0, 20)

	if current_path != "":
		_select_item_by_path(current_path)

func _select_item_by_path(path: String) -> void:
	if not is_instance_valid(tree):
		return
	var root := tree.get_root()
	if not root:
		return
	for item in root.get_children():
		if item.get_metadata(0) == path:
			item.select(0)
			return


func _on_tree_item_selected() -> void:
	if not is_instance_valid(tree):
		return
	var item := tree.get_selected()
	if not item:
		return
	var path = item.get_metadata(0)
	if path == null:
		return
	_load_status_effect(path)


func _load_status_effect(path: String) -> void:
	current_path = path
	current_res = load(path)
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	if is_instance_valid(save_button): save_button.disabled = true
	if is_instance_valid(revert_button): revert_button.disabled = true
	var display_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	if is_instance_valid(status_label): status_label.text = "Editing: " + display_name


func _populate_form() -> void:
	suppress_signals = true

	var cur_script = current_res.get_script()
	var selected_scr_idx := 0
	for idx in range(loaded_status_scripts.size()):
		var info = loaded_status_scripts[idx]
		if info.script == cur_script:
			selected_scr_idx = idx
			break

	class_type_select.select(selected_scr_idx)
	_build_dynamic_fields_for_custom_type()

	name_edit.text = current_res.name if current_res.name != null else ""
	duration_edit.value = current_res.turn_duration
	round_start_check.button_pressed = bool(current_res.round_start)
	after_action_check.button_pressed = bool(current_res.after_action)
	turn_start_check.button_pressed = bool(current_res.turn_start)
	contribute_mult_check.button_pressed = bool(current_res.contribute_multipler)
	icon_preview.texture = current_res.icon

	if current_res.stat_changes:
		for stat_name in stat_change_edits.keys():
			if stat_name is String and stat_change_edits.has(stat_name):
				stat_change_edits[stat_name].value = current_res.stat_changes.get(stat_name)

	if is_instance_valid(affinity_display) and current_res.elemental_affinity_change != null:
		affinity_display.display_affinities(current_res.elemental_affinity_change)

	suppress_signals = false


func _on_field_changed() -> void:
	if suppress_signals or not current_res:
		return
	_apply_form_to_resource()
	dirty = true
	if is_instance_valid(save_button): save_button.disabled = false
	if is_instance_valid(revert_button): revert_button.disabled = false
	var display_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	if is_instance_valid(status_label): status_label.text = "Unsaved changes to '" + display_name + "'"


func _apply_form_to_resource() -> void:
	current_res.name = name_edit.text
	current_res.turn_duration = int(duration_edit.value)
	current_res.round_start = round_start_check.button_pressed
	current_res.after_action = after_action_check.button_pressed
	current_res.turn_start = turn_start_check.button_pressed
	current_res.contribute_multipler = contribute_mult_check.button_pressed
	current_res.icon = icon_preview.texture

	for p_name in dynamic_controls.keys():
		var ctrl = dynamic_controls[p_name]
		if ctrl is SpinBox:
			current_res.set(p_name, ctrl.value)
		elif ctrl is CheckBox:
			current_res.set(p_name, ctrl.button_pressed)
		elif ctrl is LineEdit:
			current_res.set(p_name, ctrl.text)

	if not current_res.stat_changes:
		current_res.stat_changes = rpg_stats.new()

	for stat_name in stat_change_edits.keys():
		if stat_name is String and stat_change_edits[stat_name] is SpinBox:
			current_res.stat_changes.set(stat_name, int(stat_change_edits[stat_name].value))

	var new_affinities: Array[elemental_affinity] = []
	if is_instance_valid(affinity_display):
		var current_aff_dict: Dictionary = affinity_display.get_affinities()
		for el_name in current_aff_dict.keys():
			var val: float = current_aff_dict[el_name]
			if not is_zero_approx(val):
				var entry := elemental_affinity.new()
				if "elementalName" in entry:
					entry.elementalName = str(el_name)
				elif "element" in entry:
					entry.element = el_name
				if "affinity" in entry:
					entry.affinity = val
				new_affinities.append(entry)

	current_res.elemental_affinity_change.assign(new_affinities)


func _sanitize_filename(fname: String) -> String:
	var clean := fname.strip_edges().to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex.sub(clean, "", true)


func _on_save_pressed() -> void:
	if not current_res:
		return

	_apply_form_to_resource()

	var err := ResourceSaver.save(current_res, current_path)
	if err == OK:
		dirty = false
		if is_instance_valid(save_button): save_button.disabled = true
		if is_instance_valid(revert_button): revert_button.disabled = true
		if is_instance_valid(status_label): status_label.text = "Saved '" + current_res.name + "' to disk."
		_populate_tree()
	else:
		if is_instance_valid(status_label): status_label.text = "Save failed (error %d)" % err


func _on_revert_pressed() -> void:
	if current_path == "":
		return
	current_res = ResourceLoader.load(current_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	_populate_form()
	dirty = false
	if is_instance_valid(save_button): save_button.disabled = true
	if is_instance_valid(revert_button): revert_button.disabled = true
	if is_instance_valid(status_label): status_label.text = "Reverted '" + current_res.name + "'"
