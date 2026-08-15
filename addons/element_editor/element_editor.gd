# res://addons/element_editor/element_editor.gd
@tool
extends Control

const ELEMENT_DIR := "res://data/elements"
const STATUS_DIR := "res://data/status_effects"
const STAT_ICON_DIR := "res://sprites/GUI/stats/"
const ELEMENT_ICON_DIR := "res://sprites/GUI/elements/"

@onready var tree: Tree = %Tree
@onready var refresh_button: Button = %RefreshButton
@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

var current_path : String = ""
var current_res : element = null
var status_effects : Array = []  # Array of loaded `status_effect` resources

# Form fields
var name_edit : LineEdit
var colour_edit : ColorPickerButton
var preview_label : RichTextLabel
var icon_preview : TextureRect
var file_dialog : EditorFileDialog

var stat_increase_edits : Dictionary = {} # "strength" etc -> SpinBox (rpg_stats_increase)
var health_min_edit : SpinBox
var health_max_edit : SpinBox

# Status Effect Infliction Controls
var status_chance_edits : Dictionary = {}      # status_effect resource -> SpinBox (0 - 100%)
var status_sliders : Dictionary = {}           # status_effect resource -> HSlider
var status_enable_checks : Dictionary = {}     # status_effect resource -> CheckBox
var status_rows : Dictionary = {}              # status_effect resource -> HBoxContainer
var status_search_edit : LineEdit

var dirty : bool = false
var suppress_signals : bool = false


func _ready() -> void:
	if not is_instance_valid(tree):
		return

	_setup_file_dialog()

	refresh_button.pressed.connect(_populate_tree)
	tree.item_selected.connect(_on_tree_item_selected)
	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	for child in form_root.get_children():
		child.queue_free()

	_load_status_effects()
	_build_form()
	_set_form_enabled(false)
	call_deferred("_populate_tree")


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


func _load_status_effects() -> void:
	status_effects.clear()
	var paths := _find_resources_recursive(STATUS_DIR)
	for path in paths:
		var res = load(path)
		if res is status_effect:
			status_effects.append(res)
	status_effects.sort_custom(func(a, b): return a.name < b.name)


func _build_form() -> void:
	# ---- Identity & Visuals ----
	form_root.add_child(_section_header("Identity & Display"))

	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed(0))
	form_root.add_child(_labeled_row("Element Name", name_edit))

	colour_edit = ColorPickerButton.new()
	colour_edit.custom_minimum_size = Vector2(0, 26)
	colour_edit.color_changed.connect(func(_c): _on_field_changed(0))
	form_root.add_child(_labeled_row("Element Colour", colour_edit))

	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	preview_label.custom_minimum_size = Vector2(0, 24)
	form_root.add_child(_labeled_row("Coloured Preview", preview_label))

	# Icon Row
	var icon_hbox := HBoxContainer.new()
	icon_hbox.add_theme_constant_override("separation", 8)

	icon_preview = TextureRect.new()
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.custom_minimum_size = Vector2(32, 32)
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_hbox.add_child(icon_preview)

	var browse_btn := Button.new()
	browse_btn.text = "Choose Image..."
	browse_btn.pressed.connect(func(): file_dialog.popup_file_dialog())
	icon_hbox.add_child(browse_btn)

	var auto_btn := Button.new()
	auto_btn.text = "Auto-Detect Icon"
	auto_btn.pressed.connect(_on_auto_detect_icon)
	icon_hbox.add_child(auto_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func(): _set_icon_texture(null))
	icon_hbox.add_child(clear_btn)

	form_root.add_child(_labeled_row("Icon Texture", icon_hbox))

	form_root.add_child(_hsep())

	# ---- Elemental Status Inflict Configurator ----
	form_root.add_child(_section_header("Elemental Status Inflict (effects_to_add)"))

	# Search Bar
	status_search_edit = LineEdit.new()
	status_search_edit.placeholder_text = "Search status effects..."
	status_search_edit.text_changed.connect(_on_status_search_changed)
	form_root.add_child(_labeled_row("Filter Statuses", status_search_edit))

	# Scroll Area
	var status_scroll := ScrollContainer.new()
	status_scroll.custom_minimum_size = Vector2(0, 200)
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var status_vbox := VBoxContainer.new()
	status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_vbox.add_theme_constant_override("separation", 6)

	status_rows.clear()
	for st in status_effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var enable_cb := CheckBox.new()
		enable_cb.text = st.name
		enable_cb.custom_minimum_size = Vector2(140, 0)
		enable_cb.toggled.connect(func(_t): _on_field_changed(0))
		status_enable_checks[st] = enable_cb
		row.add_child(enable_cb)

		if st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		# Slider & SpinBox setup
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_sliders[st] = slider
		row.add_child(slider)

		var spin := _make_float_spin(0.0, 100.0, 1.0)
		spin.custom_minimum_size = Vector2(75, 0)
		status_chance_edits[st] = spin
		row.add_child(spin)

		# Sync Slider and SpinBox
		slider.value_changed.connect(func(v):
			if not suppress_signals:
				spin.value = v
		)
		spin.value_changed.connect(func(v):
			if not suppress_signals:
				slider.value = v
		)

		status_rows[st] = row
		status_vbox.add_child(row)

	status_scroll.add_child(status_vbox)
	form_root.add_child(status_scroll)

	form_root.add_child(_hsep())

	# ---- Stat Growth Modifiers ----
	form_root.add_child(_section_header("Stat Growth Modifiers (rpg_stats_increase)"))

	health_min_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Health Growth (min)", health_min_edit))

	health_max_edit = _make_int_spin(0, 99, 1)
	form_root.add_child(_labeled_row("Health Growth (max)", health_max_edit))

	var stats_list := ["strength", "vitality", "dexterity", "magic_pow", "agility", "luck"]
	for stat_name in stats_list:
		var icon := _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
		var s := _make_float_spin(0.0, 10.0, 0.01)
		stat_increase_edits[stat_name] = s
		form_root.add_child(_labeled_row(stat_name.capitalize() + " Rate", s, icon))


func _on_status_search_changed(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for st in status_rows.keys():
		var row: HBoxContainer = status_rows[st]
		if filter == "" or st.name.to_lower().contains(filter):
			row.visible = true
		else:
			row.visible = false


func _on_icon_file_selected(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			_set_icon_texture(tex)


func _on_auto_detect_icon() -> void:
	if not current_res:
		return
	var tex := _load_gui_icon(ELEMENT_ICON_DIR, "elements_", current_res.name)
	if tex:
		_set_icon_texture(tex)
	else:
		status_label.text = "No icon found matching 'elements_%s.png'" % current_res.name.to_lower()


func _set_icon_texture(tex: Texture2D) -> void:
	if not current_res or _is_none_element():
		return
	current_res.icon = tex
	icon_preview.texture = tex
	_on_field_changed(0)


func _is_none_element() -> bool:
	if not current_res:
		return false
	return current_res.name.to_lower() == "none" or current_path.get_file().to_lower() == "none.tres"


func _set_form_enabled(enabled: bool) -> void:
	var can_edit := enabled and not _is_none_element()
	form_root.modulate.a = 1.0 if can_edit else 0.5
	_set_container_editable(form_root, can_edit)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit or child is HSlider:
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

	if not DirAccess.dir_exists_absolute(ELEMENT_DIR):
		return

	var paths := _find_resources_recursive(ELEMENT_DIR)
	paths.sort()

	for epath in paths:
		var res = load(epath)
		if res is element:
			var item := tree.create_item(root)
			item.set_text(0, res.name if res.name != "" else epath.get_file())
			item.set_metadata(0, epath)

	if current_path != "":
		_select_item_by_path(current_path)


func _select_item_by_path(path: String) -> void:
	var root := tree.get_root()
	if not root:
		return
	for item in root.get_children():
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
	_load_element(path)


func _load_element(path: String) -> void:
	current_path = path
	current_res = load(path)
	_populate_form()

	if _is_none_element():
		_set_form_enabled(false)
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "The 'None' element is a system default and cannot be edited."
	else:
		_set_form_enabled(true)
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "Editing: " + current_res.name


func _populate_form() -> void:
	suppress_signals = true

	name_edit.text = current_res.name
	colour_edit.color = current_res.colour
	icon_preview.texture = current_res.icon

	if current_res.stats:
		health_min_edit.value = current_res.stats.health_min
		health_max_edit.value = current_res.stats.health_max
		for stat_name in stat_increase_edits.keys():
			stat_increase_edits[stat_name].value = current_res.stats.get(stat_name)

	# Clear status search filter
	if status_search_edit:
		status_search_edit.text = ""
		_on_status_search_changed("")

	# Populate status effect chance values & sliders
	for st in status_effects:
		var has_status := false
		var status_chance := 100.0
		for sec in current_res.effects_to_add:
			if sec and (sec.status == st or (sec.status and sec.status.name == st.name)):
				has_status = true
				status_chance = sec.chance * 100.0
				break
		status_enable_checks[st].button_pressed = has_status
		status_chance_edits[st].value = status_chance
		status_sliders[st].value = status_chance

	_update_preview()
	suppress_signals = false


func _update_preview() -> void:
	if current_res:
		preview_label.text = current_res.get_coloured_name()


func _on_field_changed(_value) -> void:
	if suppress_signals or not current_res or _is_none_element():
		return
	_apply_form_to_resource()
	_update_preview()
	dirty = true
	save_button.disabled = false
	revert_button.disabled = false
	status_label.text = "Unsaved changes to '" + current_res.name + "'"


func _apply_form_to_resource() -> void:
	if _is_none_element():
		return

	current_res.name = name_edit.text
	current_res.colour = colour_edit.color
	current_res.icon = icon_preview.texture

	if not current_res.stats:
		current_res.stats = rpg_stats_increase.new()

	current_res.stats.health_min = int(health_min_edit.value)
	current_res.stats.health_max = int(health_max_edit.value)
	for stat_name in stat_increase_edits.keys():
		current_res.stats.set(stat_name, stat_increase_edits[stat_name].value)

	# Save elemental effects_to_add array
	var new_effects : Array[status_effect_chance] = []
	for st in status_effects:
		if status_enable_checks[st].button_pressed:
			var sec := status_effect_chance.new()
			sec.status = st
			sec.chance = status_chance_edits[st].value / 100.0
			new_effects.append(sec)
	current_res.effects_to_add = new_effects


func _on_save_pressed() -> void:
	if not current_res or _is_none_element():
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

	if _is_none_element():
		_set_form_enabled(false)
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "The 'None' element is a system default and cannot be edited."
	else:
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		status_label.text = "Reverted '" + current_res.name + "'"
