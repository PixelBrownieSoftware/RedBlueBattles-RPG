# res://addons/status_effect_editor/status_effect_editor.gd
@tool
extends Control

const STATUS_DIR := "res://data/status_effects"
const ELEMENT_DIR := "res://data/elements"
const STAT_ICON_DIR := "res://sprites/GUI/stats/"

var tree: Tree
var refresh_button: Button
var new_status_button: Button
var save_button: Button
var revert_button: Button
var status_label: Label
var form_root: VBoxContainer

var current_path : String = ""
var current_res : status_effect = null
var elements : Array = []

# Form Controls
var name_edit : LineEdit
var duration_edit : SpinBox

var round_start_check : CheckBox
var after_action_check : CheckBox
var turn_start_check : CheckBox
var contribute_mult_check : CheckBox

var icon_preview : TextureRect
var file_dialog : EditorFileDialog

var stat_change_edits : Dictionary = {}
var affinity_display : ElementalAffinityDisplay

var dirty : bool = false
var suppress_signals : bool = false


func _ready() -> void:
	_bind_ui_nodes()
	_setup_file_dialog()

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


func _build_form() -> void:
	if not is_instance_valid(form_root):
		return

	# ---- Identity & Duration ----
	form_root.add_child(_section_header("Identity & Duration"))

	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Effect Name", name_edit))

	duration_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Turn Duration", duration_edit))

	form_root.add_child(_hsep())

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
	affinity_display.default_value = 0.0 # Status effects default to 0.0
	affinity_display.custom_minimum_size = Vector2(0, 100)
	affinity_display.affinity_changed.connect(func(_el, _val): _on_field_changed())
	form_root.add_child(affinity_display)


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


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child == affinity_display:
			continue
		if child is SpinBox or child is LineEdit:
			child.editable = enabled
		elif child is Button or child is ColorPickerButton or child is CheckBox:
			child.disabled = not enabled
		else:
			_set_container_editable(child, enabled)


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

	# Ensure display_affinities is safely passed the existing resource array
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

	if not current_res.stat_changes:
		current_res.stat_changes = rpg_stats.new()

	for stat_name in stat_change_edits.keys():
		if stat_name is String and stat_change_edits[stat_name] is SpinBox:
			current_res.stat_changes.set(stat_name, int(stat_change_edits[stat_name].value))

	# Rebuild elemental affinities using 0 as neutral base
	var new_affinities: Array[elemental_affinity] = []
	if is_instance_valid(affinity_display):
		var current_aff_dict: Dictionary = affinity_display.get_affinities()
		for el_name in current_aff_dict.keys():
			var val: float = current_aff_dict[el_name]
			# Only save entries that are non-zero!
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

	var target_path := current_path
	var clean_name := _sanitize_filename(current_res.name)

	if clean_name != "":
		var desired_path := STATUS_DIR.path_join(clean_name + ".tres")
		if desired_path != current_path:
			if FileAccess.file_exists(desired_path):
				var count := 1
				while FileAccess.file_exists(STATUS_DIR.path_join(clean_name + "_" + str(count) + ".tres")):
					count += 1
				desired_path = STATUS_DIR.path_join(clean_name + "_" + str(count) + ".tres")

			var rename_err := DirAccess.rename_absolute(current_path, desired_path)
			if rename_err == OK:
				target_path = desired_path
				current_path = desired_path

	var err := ResourceSaver.save(current_res, target_path)
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
