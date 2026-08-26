# res://addons/skill_editor/skill_editor.gd
@tool
extends Control

const SKILL_DIR := "res://data/skills"
const ELEMENT_DIR := "res://data/elements"
const STATUS_DIR := "res://data/status_effects"
const STAT_ICON_DIR := "res://sprites/GUI/stats/"
const SCRIPT_DIR := "res://src/scripts/skill/"

@onready var element_filter_select: OptionButton = %ElementFilterSelect
@onready var search_bar: LineEdit = %SearchBar
@onready var refresh_button: Button = %RefreshButton
@onready var new_skill_button: Button = %NewSkillButton
@onready var skill_list: ItemList = %SkillList

@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

# File Management UI Controls
var rename_button: Button
var delete_button: Button
var rename_dialog: ConfirmationDialog
var rename_input: LineEdit
var delete_confirm_dialog: ConfirmationDialog

var current_path : String = ""
var current_res : rpg_skill = null
var elements : Array = []        # Array of loaded element resources
var status_effects : Array = []  # Array of loaded status_effect resources
var loaded_skills : Array = []   # Array of { "path": String, "res": rpg_skill }
var loaded_skill_scripts : Array[Dictionary] = [] # Array of { "display_name": String, "path": String, "script": Script }

# Class Type Selector Controls
var class_type_select : OptionButton
var dynamic_fields_vbox : VBoxContainer
var dynamic_controls : Dictionary = {}

# Skill Animation Controls
var anim_vbox : VBoxContainer

# Base Form Controls
var name_edit : LineEdit
var learnable_check : CheckBox
var usable_anyone_check : CheckBox
var can_select_defeated : CheckBox
var power_edit : SpinBox
var stamina_cost_edit : SpinBox
var repeat_min_edit : SpinBox
var repeat_max_edit : SpinBox
var scope_select : OptionButton
var element_select : OptionButton

var icon_preview : TextureRect
var file_dialog : EditorFileDialog

var stat_req_edits : Dictionary = {}
var status_add_checks : Dictionary = {}
var status_add_rows : Dictionary = {}
var status_remove_checks : Dictionary = {}
var status_remove_rows : Dictionary = {}

# Effects to Add active controls
var status_active_vbox : VBoxContainer
var active_status_sliders : Dictionary = {}
var active_status_labels : Dictionary = {}
var active_status_chances : Dictionary = {}

# Effects to Remove active controls
var status_remove_active_vbox : VBoxContainer

var elemental_status_label : RichTextLabel
var status_add_search_edit : LineEdit
var status_remove_search_edit : LineEdit

var dirty : bool = false
var suppress_signals : bool = false


func _ready() -> void:
	if not is_instance_valid(skill_list):
		return

	_setup_file_dialog()
	_setup_file_management_ui()

	refresh_button.pressed.connect(_refresh_all)
	search_bar.text_changed.connect(func(_q): _filter_and_populate_list())
	element_filter_select.item_selected.connect(func(_idx): _filter_and_populate_list())
	skill_list.item_selected.connect(_on_skill_selected)
	new_skill_button.pressed.connect(_on_new_skill_pressed)

	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	_set_form_enabled(false)
	call_deferred("_refresh_all")


func _setup_file_management_ui() -> void:
	var toolbar: HBoxContainer = %SaveButton.get_parent()

	rename_button = Button.new()
	rename_button.text = "Rename File"
	rename_button.disabled = true
	rename_button.pressed.connect(_on_rename_pressed)
	toolbar.add_child(rename_button)
	toolbar.move_child(rename_button, 1)

	delete_button = Button.new()
	delete_button.text = "Delete File"
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_pressed)
	toolbar.add_child(delete_button)
	toolbar.move_child(delete_button, 2)

	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Skill Resource"
	rename_dialog.size = Vector2i(350, 100)

	var vbox := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Enter new file name:"
	vbox.add_child(lbl)

	rename_input = LineEdit.new()
	rename_input.placeholder_text = "new_skill_name"
	vbox.add_child(rename_input)

	rename_dialog.add_child(vbox)
	rename_dialog.confirmed.connect(_confirm_rename)
	add_child(rename_dialog)

	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "Delete Skill Resource?"
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete this skill file permanently?"
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
		status_label.text = "Rename failed: File '%s' already exists!" % new_name
		return

	var err := DirAccess.rename_absolute(current_path, new_full_path)
	if err == OK:
		current_path = new_full_path
		status_label.text = "Renamed file to: " + new_name
		_load_all_skills()
		_filter_and_populate_list()
	else:
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
		status_label.text = "Deleted skill: " + file_to_delete.get_file()
		current_path = ""
		current_res = null
		_set_form_enabled(false)
		_load_all_skills()
		_filter_and_populate_list()
	else:
		status_label.text = "Failed to delete file (error %d)" % err


func _refresh_all() -> void:
	_ensure_directories_exist()
	_load_elements()
	_load_status_effects()
	_load_skill_scripts()
	_build_form()
	_populate_element_filter_dropdown()
	_load_all_skills()
	_filter_and_populate_list()

	if current_path != "":
		_load_skill(current_path)


func _ensure_directories_exist() -> void:
	for dir_path in [SKILL_DIR, ELEMENT_DIR, STATUS_DIR, SCRIPT_DIR]:
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
		if res and ("name" in res or "element_name" in res):
			elements.append(res)

	elements.sort_custom(func(a, b): 
		var a_name: String = a.name if "name" in a else ""
		var b_name: String = b.name if "name" in b else ""
		return a_name < b_name
	)


func _populate_element_filter_dropdown() -> void:
	element_filter_select.clear()
	element_filter_select.add_item("All Elements", 0)
	element_filter_select.set_item_metadata(0, null)

	for idx in range(elements.size()):
		var el = elements[idx]
		var item_idx := idx + 1
		var el_name: String = el.name if "name" in el else "Element " + str(item_idx)
		element_filter_select.add_item(el_name, item_idx)
		element_filter_select.set_item_metadata(item_idx, el)


func _load_status_effects() -> void:
	status_effects.clear()
	var paths := _find_resources_recursive(STATUS_DIR)
	for path in paths:
		var res = load(path)
		if res and ("name" in res or "status_name" in res):
			status_effects.append(res)

	status_effects.sort_custom(func(a, b): 
		var a_name: String = a.name if "name" in a else ""
		var b_name: String = b.name if "name" in b else ""
		return a_name < b_name
	)


func _load_skill_scripts() -> void:
	loaded_skill_scripts.clear()
	
	loaded_skill_scripts.append({
		"display_name": "Base Skill (rpg_skill)",
		"path": "",
		"script": rpg_skill
	})

	if DirAccess.dir_exists_absolute(SCRIPT_DIR):
		var paths := _find_resources_recursive(SCRIPT_DIR, [".gd"])
		paths.sort()
		for path in paths:
			var scr = load(path) as Script
			if scr:
				var script_name := path.get_file().get_basename()
				var global_name := scr.get_global_name()
				var display_name: String = (global_name if global_name != "" else script_name) + " (" + script_name + ".gd)"
				loaded_skill_scripts.append({
					"display_name": display_name,
					"path": path,
					"script": scr
				})


func _load_all_skills() -> void:
	loaded_skills.clear()
	var paths := _find_resources_recursive(SKILL_DIR, [".tres", ".res"])
	paths.sort()

	for spath in paths:
		var res = load(spath)
		if res is rpg_skill or (res and "power" in res):
			loaded_skills.append({
				"path": spath,
				"res": res
			})


func _filter_and_populate_list() -> void:
	skill_list.clear()

	var search_filter := search_bar.text.strip_edges().to_lower()
	var selected_elem_idx := element_filter_select.selected

	var filter_element = null
	if selected_elem_idx > 0 and selected_elem_idx < element_filter_select.get_item_count():
		filter_element = element_filter_select.get_item_metadata(selected_elem_idx)

	for item in loaded_skills:
		var spath: String = item.path
		var sk = item.res

		var skill_name: String = sk.name if ("name" in sk and sk.name != "") else spath.get_file().get_basename()
		var matches_text := (search_filter == "" or skill_name.to_lower().contains(search_filter) or spath.get_file().to_lower().contains(search_filter))

		var sk_elem = sk.skill_element if "skill_element" in sk else (sk.element if "element" in sk else null)
		var matches_element = (filter_element == null or sk_elem == filter_element)

		if matches_text and matches_element:
			var idx := skill_list.add_item(skill_name)
			skill_list.set_item_metadata(idx, spath)

			var elem_color := _get_element_color(sk_elem)
			skill_list.set_item_custom_fg_color(idx, elem_color)

			var elem_icon := _get_element_texture(sk_elem)
			if elem_icon:
				skill_list.set_item_icon(idx, elem_icon)

			if spath == current_path:
				skill_list.select(idx)


func _get_element_color(el) -> Color:
	if not el:
		return Color.WHITE
	if "colour" in el and el.colour is Color:
		return el.colour
	if "color" in el and el.color is Color:
		return el.color
	return Color.WHITE


func _get_element_texture(el) -> Texture2D:
	if not el:
		return null
	if "icon" in el and el.icon is Texture2D:
		return el.icon
	if "texture" in el and el.texture is Texture2D:
		return el.texture
	return null


func _on_skill_selected(index: int) -> void:
	if index >= 0 and index < skill_list.get_item_count():
		var path: String = skill_list.get_item_metadata(index)
		if path != "":
			_load_skill(path)


func _on_new_skill_pressed() -> void:
	_ensure_directories_exist()

	var base_filename := "new_skill"
	var file_path := SKILL_DIR.path_join(base_filename + ".tres")
	var count := 1
	while FileAccess.file_exists(file_path):
		file_path = SKILL_DIR.path_join(base_filename + "_" + str(count) + ".tres")
		count += 1

	var new_res := rpg_skill.new()
	new_res.name = "New Skill " + str(count)

	var err := ResourceSaver.save(new_res, file_path)
	if err == OK:
		_refresh_all()
		_load_skill(file_path)
		status_label.text = "Created new skill at: " + file_path
	else:
		status_label.text = "Failed to create skill file (error %d)" % err


func _build_form() -> void:
	for child in form_root.get_children():
		child.queue_free()

	# ---- Class Type Selector ----
	form_root.add_child(_section_header("Skill Script Class (res://src/scripts/skill/)"))

	class_type_select = OptionButton.new()
	class_type_select.clear()
	for idx in range(loaded_skill_scripts.size()):
		var info := loaded_skill_scripts[idx]
		class_type_select.add_item("📜 " + info.display_name, idx)
		class_type_select.set_item_metadata(idx, info)

	class_type_select.item_selected.connect(_on_class_type_changed)
	form_root.add_child(_labeled_row("Script Class", class_type_select))

	form_root.add_child(_hsep())

	# ---- General Attributes ----
	form_root.add_child(_section_header("General Attributes"))

	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Skill Name", name_edit))

	learnable_check = CheckBox.new()
	learnable_check.text = "Can be learned by characters"
	learnable_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Learnable", learnable_check))

	usable_anyone_check = CheckBox.new()
	usable_anyone_check.text = "Usable by anyone (e.g., Pass, status skills)"
	usable_anyone_check.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Usable By Anyone", usable_anyone_check))

	can_select_defeated = CheckBox.new()
	can_select_defeated.text = "Can select defeated characters"
	can_select_defeated.toggled.connect(func(_t): _on_field_changed())
	form_root.add_child(_labeled_row("Can Select Defeated", can_select_defeated))
	
	form_root.add_child(_hsep())

	# ---- Dynamic Custom Fields Container ----
	dynamic_fields_vbox = VBoxContainer.new()
	dynamic_fields_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(dynamic_fields_vbox)

	# ---- Combat Parameters ----
	form_root.add_child(_section_header("Combat Parameters"))

	power_edit = _make_int_spin(0, 999, 1)
	form_root.add_child(_labeled_row("Power", power_edit))

	stamina_cost_edit = _make_int_spin(0, 999, 1)
	form_root.add_child(_labeled_row("Stamina Cost", stamina_cost_edit))

	repeat_min_edit = _make_int_spin(1, 99, 1)
	form_root.add_child(_labeled_row("Repeat Min", repeat_min_edit))

	repeat_max_edit = _make_int_spin(1, 99, 1)
	form_root.add_child(_labeled_row("Repeat Max", repeat_max_edit))

	scope_select = OptionButton.new()
	scope_select.add_item("NONE (-1)", rpg_skill.SCOPE.NONE)
	scope_select.add_item("FOE", rpg_skill.SCOPE.FOE)
	scope_select.add_item("ALLY", rpg_skill.SCOPE.ALLY)
	scope_select.add_item("ALL", rpg_skill.SCOPE.ALL)
	scope_select.add_item("SELF", rpg_skill.SCOPE.SELF)
	scope_select.item_selected.connect(func(_i): _on_field_changed())
	form_root.add_child(_labeled_row("Scope", scope_select))

	element_select = OptionButton.new()
	element_select.item_selected.connect(_on_element_changed)
	form_root.add_child(_labeled_row("Skill Element", element_select))

	form_root.add_child(_hsep())

	# ---- Skill Animation Sequence Editor ----
	form_root.add_child(_section_header("Skill Animations (skill_animation)"))

	anim_vbox = VBoxContainer.new()
	anim_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(anim_vbox)

	var add_anim_btn := Button.new()
	add_anim_btn.text = "+ Add Animation Step"
	add_anim_btn.pressed.connect(func():
		_add_animation_step_card(rpg_skill_animation.new())
		_on_field_changed()
	)
	form_root.add_child(add_anim_btn)

	form_root.add_child(_hsep())

	# ---- Elemental Status Inflict Readout ----
	form_root.add_child(_section_header("Elemental Status Inflict (Inherited from Element)"))
	elemental_status_label = RichTextLabel.new()
	elemental_status_label.bbcode_enabled = true
	elemental_status_label.fit_content = true
	elemental_status_label.custom_minimum_size = Vector2(0, 24)
	form_root.add_child(_labeled_row("Element Inflicts", elemental_status_label))

	form_root.add_child(_hsep())

	# ---- Skill Status Inflict Configurator (effects_to_add) ----
	form_root.add_child(_section_header("Skill Status Inflict (effects_to_add)"))

	var active_hdr := Label.new()
	active_hdr.text = "Active Status Effects to Inflict (Adjust Chance 0% - 100%):"
	form_root.add_child(active_hdr)

	status_active_vbox = VBoxContainer.new()
	status_active_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(status_active_vbox)

	form_root.add_child(HSeparator.new())

	status_add_search_edit = LineEdit.new()
	status_add_search_edit.placeholder_text = "Search status effects to toggle..."
	status_add_search_edit.clear_button_enabled = true
	status_add_search_edit.text_changed.connect(func(q): _filter_status_rows(q, status_add_rows))
	form_root.add_child(_labeled_row("Filter Add Statuses", status_add_search_edit))

	var add_status_scroll := ScrollContainer.new()
	add_status_scroll.custom_minimum_size = Vector2(0, 140)
	add_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var add_status_vbox := VBoxContainer.new()
	add_status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_status_vbox.add_theme_constant_override("separation", 4)

	status_add_rows.clear()
	status_add_checks.clear()

	for st in status_effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var st_name: String = st.name if "name" in st else "Status"
		var enable_cb := CheckBox.new()
		enable_cb.text = st_name
		enable_cb.custom_minimum_size = Vector2(160, 0)
		enable_cb.toggled.connect(func(is_checked):
			_toggle_status_active(st, is_checked)
			_on_field_changed()
		)
		status_add_checks[st] = enable_cb
		row.add_child(enable_cb)

		if "icon" in st and st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		status_add_rows[st] = row
		add_status_vbox.add_child(row)

	add_status_scroll.add_child(add_status_vbox)
	form_root.add_child(add_status_scroll)

	form_root.add_child(_hsep())

	# ---- Skill Status Cleansing Configurator (effects_to_remove) ----
	form_root.add_child(_section_header("Statuses to Remove (effects_to_remove)"))

	var remove_active_hdr := Label.new()
	remove_active_hdr.text = "Active Status Effects to Cleansed/Removed:"
	form_root.add_child(remove_active_hdr)

	status_remove_active_vbox = VBoxContainer.new()
	status_remove_active_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(status_remove_active_vbox)

	form_root.add_child(HSeparator.new())

	status_remove_search_edit = LineEdit.new()
	status_remove_search_edit.placeholder_text = "Search status effects to cleanse..."
	status_remove_search_edit.clear_button_enabled = true
	status_remove_search_edit.text_changed.connect(func(q): _filter_status_rows(q, status_remove_rows))
	form_root.add_child(_labeled_row("Filter Remove Statuses", status_remove_search_edit))

	var remove_status_scroll := ScrollContainer.new()
	remove_status_scroll.custom_minimum_size = Vector2(0, 140)
	remove_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var remove_status_vbox := VBoxContainer.new()
	remove_status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_status_vbox.add_theme_constant_override("separation", 4)

	status_remove_rows.clear()
	status_remove_checks.clear()

	for st in status_effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var st_name: String = st.name if "name" in st else "Status"
		var remove_cb := CheckBox.new()
		remove_cb.text = st_name
		remove_cb.custom_minimum_size = Vector2(160, 0)
		remove_cb.toggled.connect(func(is_checked):
			_toggle_status_remove_active(st, is_checked)
			_on_field_changed()
		)
		status_remove_checks[st] = remove_cb
		row.add_child(remove_cb)

		if "icon" in st and st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		status_remove_rows[st] = row
		remove_status_vbox.add_child(row)

	remove_status_scroll.add_child(remove_status_vbox)
	form_root.add_child(remove_status_scroll)

	form_root.add_child(_hsep())

	# ---- Visuals ----
	form_root.add_child(_section_header("Visuals"))

	var icon_hbox := HBoxContainer.new()
	icon_hbox.add_theme_constant_override("separation", 8)

	icon_preview = TextureRect.new()
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.custom_minimum_size = Vector2(32, 32)
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_hbox.add_child(icon_preview)

	var browse_btn := Button.new()
	browse_btn.text = "Choose Custom Icon..."
	browse_btn.pressed.connect(func(): file_dialog.popup_file_dialog())
	icon_hbox.add_child(browse_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(func(): _set_icon_texture(null))
	icon_hbox.add_child(clear_btn)

	form_root.add_child(_labeled_row("Custom Icon", icon_hbox))

	form_root.add_child(_hsep())

	# ---- Stat Requirements ----
	form_root.add_child(_section_header("Stat Requirements"))
	stat_req_edits.clear()
	var stats_list := ["strength", "vitality", "dexterity", "magic_pow", "agility", "luck"]
	for stat_name in stats_list:
		var icon := _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
		var s := _make_int_spin(0, 999, 1)
		stat_req_edits[stat_name] = s
		form_root.add_child(_labeled_row(stat_name.capitalize() + " Req", s, icon))


func _on_class_type_changed(idx: int) -> void:
	if not current_res or idx < 0 or idx >= loaded_skill_scripts.size():
		return

	var info: Dictionary = loaded_skill_scripts[idx]
	var target_script: Script = info.script

	if current_res.get_script() == target_script:
		return

	var new_inst = target_script.new() if target_script else rpg_skill.new()

	if "name" in current_res and "name" in new_inst: new_inst.name = current_res.name
	if "learnable" in current_res and "learnable" in new_inst: new_inst.learnable = current_res.learnable
	if "usable_by_anyone" in current_res and "usable_by_anyone" in new_inst: new_inst.usable_by_anyone = current_res.usable_by_anyone
	if "can_select_inactive" in current_res and "can_select_inactive" in new_inst: new_inst.can_select_inactive = current_res.can_select_inactive
	if "power" in current_res and "power" in new_inst: new_inst.power = current_res.power
	if "stamina_cost" in current_res and "stamina_cost" in new_inst: new_inst.stamina_cost = current_res.stamina_cost
	if "repeat_min" in current_res and "repeat_min" in new_inst: new_inst.repeat_min = current_res.repeat_min
	if "repeat_max" in current_res and "repeat_max" in new_inst: new_inst.repeat_max = current_res.repeat_max
	if "skill_scope" in current_res and "skill_scope" in new_inst: new_inst.skill_scope = current_res.skill_scope
	if "skill_element" in current_res and "skill_element" in new_inst: new_inst.skill_element = current_res.skill_element
	if "custom_icon" in current_res and "custom_icon" in new_inst: new_inst.custom_icon = current_res.custom_icon
	if "skill_animation" in current_res and "skill_animation" in new_inst: new_inst.skill_animation = current_res.skill_animation

	current_res = new_inst
	_populate_form()
	_on_field_changed()


func _build_dynamic_fields_for_custom_type() -> void:
	for child in dynamic_fields_vbox.get_children():
		child.queue_free()

	dynamic_controls.clear()

	if not current_res:
		return

	var base_properties := ["script", "Built-in Script", "name", "learnable", "usable_by_anyone", "can_select_inactive",
		"power", "stamina_cost", "repeat_min", "repeat_max", "skill_scope", "skill_element", "element",
		"skill_animation", "effects_to_add", "effects_to_remove", "custom_icon", "stat_requirement"]

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
	dynamic_fields_vbox.add_child(_section_header("Custom Script Properties (" + scr_name + ")"))

	for p in custom_props:
		var p_name: String = p.name
		var p_type: int = p.type
		var p_class: String = p.class_name
		var val = current_res.get(p_name)

		# Custom handling for Elemental Affinity Change arrays -> renders interactive sliders
		if p_name == "elemental_affinity_change" or (p_type == TYPE_ARRAY and "elemental_affinity" in p.hint_string):
			var aff_disp := ElementalAffinityDisplay.new()
			aff_disp.upper_lower_limit = Vector2(-2.0, 2.0)
			aff_disp.default_value = 0.0
			aff_disp.custom_minimum_size = Vector2(0, 120)
			aff_disp.affinity_changed.connect(func(_el, _v): _on_field_changed())
			dynamic_controls[p_name] = aff_disp
			dynamic_fields_vbox.add_child(_section_header(p_name.capitalize() + " (-2 to +2 Sliders)"))
			dynamic_fields_vbox.add_child(aff_disp)
			continue

		# Custom handling for rpg_stats properties -> renders stat spinboxes with icons
		if p_class == "rpg_stats" or p_name == "stat_changes" or p_name == "stat_modifier" or p_name == "stat_requirements":
			var stats_group := VBoxContainer.new()
			stats_group.add_theme_constant_override("separation", 4)
			var stat_spin_dict: Dictionary = {}
			var stats_list := ["strength", "vitality", "dexterity", "magic_pow", "agility", "luck"]

			for stat_name in stats_list:
				var icon := _load_gui_icon(STAT_ICON_DIR, "gui_", stat_name)
				var spin := _make_int_spin(-999, 999, 1)
				stat_spin_dict[stat_name] = spin
				stats_group.add_child(_labeled_row(stat_name.capitalize() + " Change", spin, icon))

			dynamic_controls[p_name] = stat_spin_dict
			dynamic_fields_vbox.add_child(_section_header(p_name.capitalize() + " (rpg_stats)"))
			dynamic_fields_vbox.add_child(stats_group)
			continue

		match p_type:
			TYPE_BOOL:
				var cb := CheckBox.new()
				cb.button_pressed = bool(val)
				cb.toggled.connect(func(_t): _on_field_changed())
				dynamic_controls[p_name] = cb
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), cb))

			TYPE_INT:
				if p.hint == PROPERTY_HINT_ENUM:
					var opt := OptionButton.new()
					var enum_entries: PackedStringArray = p.hint_string.split(",")
					for e_idx in range(enum_entries.size()):
						var entry := enum_entries[e_idx].strip_edges()
						var kv: PackedStringArray = entry.split(":")
						var key_name := kv[0]
						var val_int := int(kv[1]) if kv.size() > 1 else e_idx
						opt.add_item(key_name, val_int)
						opt.set_item_metadata(e_idx, val_int)
						if val == val_int:
							opt.select(e_idx)

					opt.item_selected.connect(func(_i): _on_field_changed())
					dynamic_controls[p_name] = opt
					dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), opt))
				else:
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

			TYPE_COLOR:
				var cpb := ColorPickerButton.new()
				cpb.color = val if val is Color else Color.WHITE
				cpb.custom_minimum_size = Vector2(0, 26)
				cpb.color_changed.connect(func(_c): _on_field_changed())
				dynamic_controls[p_name] = cpb
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), cpb))

			TYPE_OBJECT:
				var row := HBoxContainer.new()
				var path_lbl := Label.new()
				path_lbl.text = (val.resource_path.get_file() if val and val is Resource and val.resource_path != "" else ("Assigned Object" if val else "Null"))
				path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(path_lbl)
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), row))

			TYPE_ARRAY:
				var lbl := Label.new()
				var arr_size: int = val.size() if val is Array else 0
				lbl.text = "Array (" + str(arr_size) + " items)"
				dynamic_fields_vbox.add_child(_labeled_row(p_name.capitalize(), lbl))


func _add_animation_step_card(anim_res: rpg_skill_animation = null) -> void:
	if not anim_res:
		anim_res = rpg_skill_animation.new()

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.28, 0.9)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var type_lbl := Label.new()
	type_lbl.text = "Type:"
	row.add_child(type_lbl)

	var type_select := OptionButton.new()
	type_select.add_item("CALCULATION", rpg_skill_animation.SKILL_ANIMATION_TYPE.CALCULATION)
	type_select.add_item("MOVE_TO", rpg_skill_animation.SKILL_ANIMATION_TYPE.MOVE_TO)
	type_select.add_item("ANIMATION", rpg_skill_animation.SKILL_ANIMATION_TYPE.ANIMATION)
	type_select.add_item("WAIT", rpg_skill_animation.SKILL_ANIMATION_TYPE.WAIT)
	type_select.add_item("FX_ANIMATION", rpg_skill_animation.SKILL_ANIMATION_TYPE.FX_ANIMATION)

	type_select.select(anim_res.skill_animation)
	type_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_select.item_selected.connect(func(_i): _on_field_changed())
	row.add_child(type_select)

	var name_lbl := Label.new()
	name_lbl.text = "Anim Name:"
	row.add_child(name_lbl)

	var name_input := LineEdit.new()
	name_input.text = anim_res.animation_name
	name_input.placeholder_text = "e.g., attack_slash"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(_t): _on_field_changed())
	row.add_child(name_input)

	var time_lbl := Label.new()
	time_lbl.text = "Time:"
	row.add_child(time_lbl)

	var time_spin := SpinBox.new()
	time_spin.min_value = -1.0
	time_spin.max_value = 99.0
	time_spin.step = 0.05
	time_spin.value = anim_res.time_amount
	time_spin.value_changed.connect(func(_v): _on_field_changed())
	row.add_child(time_spin)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func():
		card.queue_free()
		_on_field_changed()
	)
	row.add_child(del_btn)

	card.add_child(row)
	card.set_meta("anim_instance", anim_res)
	card.set_meta("type_select", type_select)
	card.set_meta("name_input", name_input)
	card.set_meta("time_spin", time_spin)

	anim_vbox.add_child(card)


func _toggle_status_active(st, is_active: bool, chance_val: float = 100.0) -> void:
	if not active_status_chances.has(st):
		active_status_chances[st] = chance_val

	if is_active:
		_render_active_status_card(st)
	else:
		_remove_active_status_card(st)


func _render_active_status_card(st) -> void:
	if active_status_sliders.has(st):
		return

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.32, 0.22, 0.85)
	style.border_color = Color(0.35, 0.75, 0.42, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var st_name: String = st.name if "name" in st else "Status"

	if "icon" in st and st.icon:
		var tr := TextureRect.new()
		tr.texture = st.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(20, 20)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = st_name
	name_lbl.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = active_status_chances.get(st, 100.0)

	var val_lbl := Label.new()
	val_lbl.text = "Chance: %d%%" % int(slider.value)
	val_lbl.custom_minimum_size = Vector2(100, 0)

	slider.value_changed.connect(func(v):
		val_lbl.text = "Chance: %d%%" % int(v)
		active_status_chances[st] = v
		_on_field_changed()
	)

	row.add_child(slider)
	row.add_child(val_lbl)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		if status_add_checks.has(st):
			status_add_checks[st].button_pressed = false
		_remove_active_status_card(st)
		_on_field_changed()
	)
	row.add_child(remove_btn)

	panel.add_child(row)
	panel.set_meta("status_ref", st)
	status_active_vbox.add_child(panel)

	active_status_sliders[st] = slider
	active_status_labels[st] = val_lbl


func _remove_active_status_card(st) -> void:
	active_status_sliders.erase(st)
	active_status_labels.erase(st)

	for card in status_active_vbox.get_children():
		if card.get_meta("status_ref") == st:
			card.queue_free()


func _toggle_status_remove_active(st, is_active: bool) -> void:
	if is_active:
		_render_remove_status_card(st)
	else:
		_remove_remove_status_card(st)


func _render_remove_status_card(st) -> void:
	for child in status_remove_active_vbox.get_children():
		if child.has_meta("status_ref") and child.get_meta("status_ref") == st:
			return

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.18, 0.18, 0.85)
	style.border_color = Color(0.75, 0.35, 0.35, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var st_name: String = st.name if "name" in st else "Status"

	if "icon" in st and st.icon:
		var tr := TextureRect.new()
		tr.texture = st.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(20, 20)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = "Cleanses: " + st_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		if status_remove_checks.has(st):
			status_remove_checks[st].button_pressed = false
		_remove_remove_status_card(st)
		_on_field_changed()
	)
	row.add_child(remove_btn)

	panel.add_child(row)
	panel.set_meta("status_ref", st)
	status_remove_active_vbox.add_child(panel)


func _remove_remove_status_card(st) -> void:
	for card in status_remove_active_vbox.get_children():
		if card.has_meta("status_ref") and card.get_meta("status_ref") == st:
			card.queue_free()


func _filter_status_rows(query: String, row_dict: Dictionary) -> void:
	var filter := query.strip_edges().to_lower()
	for st in row_dict.keys():
		var row: Control = row_dict[st]
		var st_name: String = st.name if "name" in st else ""
		row.visible = (filter == "" or st_name.to_lower().contains(filter))


func _on_element_changed(_idx: int) -> void:
	_update_elemental_status_display()
	_on_field_changed()


func _update_elemental_status_display() -> void:
	if element_select.selected >= 0 and element_select.get_item_count() > 0:
		var chosen_el = element_select.get_item_metadata(element_select.selected)
		if chosen_el and "effects_to_add" in chosen_el and chosen_el.effects_to_add.size() > 0:
			var txt := ""
			for sec in chosen_el.effects_to_add:
				if sec and "status" in sec and sec.status:
					var s_name: String = sec.status.name if "name" in sec.status else "Status"
					var chance_val: float = sec.chance * 100.0 if "chance" in sec else 100.0
					txt += "• " + s_name + " (" + str(chance_val) + "%)\n"
			elemental_status_label.text = txt
			return
	elemental_status_label.text = "[color=gray]None[/color]"


func _on_icon_file_selected(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			_set_icon_texture(tex)


func _set_icon_texture(tex: Texture2D) -> void:
	if not current_res:
		return
	if "custom_icon" in current_res:
		current_res.custom_icon = tex
	icon_preview.texture = tex
	_on_field_changed()


func _set_form_enabled(enabled: bool) -> void:
	form_root.modulate.a = 1.0 if enabled else 0.5
	if is_instance_valid(rename_button):
		rename_button.disabled = not enabled
	if is_instance_valid(delete_button):
		delete_button.disabled = not enabled
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit or child is HSlider:
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


func _load_skill(path: String) -> void:
	current_path = path
	current_res = load(path)
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	rename_button.disabled = false
	delete_button.disabled = false
	var sk_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	status_label.text = "Editing: " + sk_name


func _populate_form() -> void:
	suppress_signals = true

	var cur_script = current_res.get_script()
	var selected_scr_idx := 0
	for idx in range(loaded_skill_scripts.size()):
		var info = loaded_skill_scripts[idx]
		if info.script == cur_script:
			selected_scr_idx = idx
			break

	class_type_select.select(selected_scr_idx)
	_build_dynamic_fields_for_custom_type()

	if "name" in current_res: name_edit.text = current_res.name
	if "learnable" in current_res: learnable_check.button_pressed = current_res.learnable
	if "usable_by_anyone" in current_res: usable_anyone_check.button_pressed = current_res.usable_by_anyone
	if "can_select_inactive" in current_res: can_select_defeated.button_pressed = bool(current_res.can_select_inactive) if current_res.can_select_inactive != null else false
	if "power" in current_res: power_edit.value = current_res.power
	if "stamina_cost" in current_res: stamina_cost_edit.value = current_res.stamina_cost
	if "repeat_min" in current_res: repeat_min_edit.value = current_res.repeat_min
	if "repeat_max" in current_res: repeat_max_edit.value = current_res.repeat_max

	element_select.clear()
	element_select.add_item("None / Neutral", 0)
	element_select.set_item_metadata(0, null)

	var selected_elem_idx := 0
	for idx in range(elements.size()):
		var el = elements[idx]
		var item_idx := idx + 1
		var el_name: String = el.name if "name" in el else "Element " + str(item_idx)
		element_select.add_item(el_name, item_idx)
		element_select.set_item_metadata(item_idx, el)

		var sk_elem = current_res.skill_element if "skill_element" in current_res else (current_res.element if "element" in current_res else null)
		if sk_elem == el:
			selected_elem_idx = item_idx

	element_select.select(selected_elem_idx)

	if "skill_scope" in current_res:
		for idx in range(scope_select.item_count):
			if scope_select.get_item_id(idx) == current_res.skill_scope:
				scope_select.select(idx)
				break

	_update_elemental_status_display()

	for c in anim_vbox.get_children():
		c.queue_free()

	if "skill_animation" in current_res and current_res.skill_animation:
		for anim in current_res.skill_animation:
			if anim:
				_add_animation_step_card(anim)

	if status_add_search_edit:
		status_add_search_edit.text = ""
		_filter_status_rows("", status_add_rows)

	if status_remove_search_edit:
		status_remove_search_edit.text = ""
		_filter_status_rows("", status_remove_rows)

	active_status_sliders.clear()
	active_status_labels.clear()
	active_status_chances.clear()
	for c in status_active_vbox.get_children():
		c.queue_free()

	for c in status_remove_active_vbox.get_children():
		c.queue_free()

	# Populate effects_to_add
	for st in status_effects:
		var has_status := false
		var status_chance := 100.0
		if "effects_to_add" in current_res and current_res.effects_to_add:
			for sec in current_res.effects_to_add:
				if sec and "status" in sec and (sec.status == st or (sec.status and "name" in sec.status and "name" in st and sec.status.name == st.name)):
					has_status = true
					if "chance" in sec: status_chance = sec.chance * 100.0
					break

		if status_add_checks.has(st):
			status_add_checks[st].button_pressed = has_status

		if has_status:
			_toggle_status_active(st, true, status_chance)

	# Populate effects_to_remove
	for st in status_effects:
		var is_cleansed := false
		if "effects_to_remove" in current_res and current_res.effects_to_remove:
			for rem_st in current_res.effects_to_remove:
				if rem_st == st or (rem_st and "name" in rem_st and "name" in st and rem_st.name == st.name):
					is_cleansed = true
					break

		if status_remove_checks.has(st):
			status_remove_checks[st].button_pressed = is_cleansed

		if is_cleansed:
			_toggle_status_remove_active(st, true)

	if "custom_icon" in current_res:
		icon_preview.texture = current_res.custom_icon

	if "stat_requirement" in current_res and current_res.stat_requirement:
		for stat_name in stat_req_edits.keys():
			if stat_name is String and stat_req_edits.has(stat_name):
				stat_req_edits[stat_name].value = current_res.stat_requirement.get(stat_name)

	# Populate custom properties controls
	for p_name in dynamic_controls.keys():
		var ctrl = dynamic_controls[p_name]
		if ctrl is ElementalAffinityDisplay:
			var existing_affinities = current_res.get(p_name)
			if existing_affinities != null:
				ctrl.display_affinities(existing_affinities)
		elif ctrl is Dictionary:
			# Handles custom rpg_stats spinbox dictionary
			var stat_res = current_res.get(p_name)
			if stat_res != null:
				for stat_name in ctrl.keys():
					if ctrl[stat_name] is SpinBox and stat_res.get(stat_name) != null:
						ctrl[stat_name].value = stat_res.get(stat_name)

	suppress_signals = false


func _on_field_changed() -> void:
	if suppress_signals or not current_res:
		return
	_apply_form_to_resource()
	dirty = true
	save_button.disabled = false
	revert_button.disabled = false
	var sk_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	status_label.text = "Unsaved changes to '" + sk_name + "'"


func _sanitize_filename(fname: String) -> String:
	var clean := fname.strip_edges().to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex.sub(clean, "", true)


func _apply_form_to_resource() -> void:
	if "name" in current_res: current_res.name = name_edit.text
	if "learnable" in current_res: current_res.learnable = learnable_check.button_pressed
	if "usable_by_anyone" in current_res: current_res.usable_by_anyone = usable_anyone_check.button_pressed
	if "can_select_inactive" in current_res: current_res.can_select_inactive = can_select_defeated.button_pressed
	if "power" in current_res: current_res.power = int(power_edit.value)
	if "stamina_cost" in current_res: current_res.stamina_cost = int(stamina_cost_edit.value)
	if "repeat_min" in current_res: current_res.repeat_min = int(repeat_min_edit.value)
	if "repeat_max" in current_res: current_res.repeat_max = int(repeat_max_edit.value)

	if "skill_scope" in current_res and scope_select.get_item_count() > 0:
		current_res.skill_scope = scope_select.get_selected_id() as rpg_skill.SCOPE

	var selected_elem_idx := element_select.selected
	var chosen_elem = element_select.get_item_metadata(selected_elem_idx) if selected_elem_idx > 0 else null

	if "skill_element" in current_res:
		current_res.skill_element = chosen_elem
	elif "element" in current_res:
		current_res.element = chosen_elem

	for p_name in dynamic_controls.keys():
		var ctrl = dynamic_controls[p_name]
		if ctrl is ElementalAffinityDisplay:
			var aff_disp := ctrl as ElementalAffinityDisplay
			var current_aff_dict: Dictionary = aff_disp.get_affinities()
			var new_affinities: Array[elemental_affinity] = []
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
			current_res.set(p_name, new_affinities)
		elif ctrl is Dictionary:
			var stat_res = current_res.get(p_name)
			if not stat_res or not (stat_res is rpg_stats):
				stat_res = rpg_stats.new()
			for stat_name in ctrl.keys():
				if ctrl[stat_name] is SpinBox:
					stat_res.set(stat_name, int(ctrl[stat_name].value))
			current_res.set(p_name, stat_res)
		elif ctrl is SpinBox:
			current_res.set(p_name, ctrl.value)
		elif ctrl is CheckBox:
			current_res.set(p_name, ctrl.button_pressed)
		elif ctrl is LineEdit:
			current_res.set(p_name, ctrl.text)
		elif ctrl is ColorPickerButton:
			current_res.set(p_name, ctrl.color)
		elif ctrl is OptionButton:
			var opt_btn := ctrl as OptionButton
			var sel_idx: int = opt_btn.selected
			if sel_idx >= 0:
				current_res.set(p_name, opt_btn.get_item_metadata(sel_idx))

	var new_anims: Array[rpg_skill_animation] = []
	for card in anim_vbox.get_children():
		var anim_res: rpg_skill_animation = card.get_meta("anim_instance")
		var type_select: OptionButton = card.get_meta("type_select")
		var name_input: LineEdit = card.get_meta("name_input")
		var time_spin: SpinBox = card.get_meta("time_spin")

		if anim_res:
			anim_res.skill_animation = type_select.selected as rpg_skill_animation.SKILL_ANIMATION_TYPE
			anim_res.animation_name = name_input.text
			anim_res.time_amount = time_spin.value
			new_anims.append(anim_res)

	if "skill_animation" in current_res:
		current_res.skill_animation.assign(new_anims)

	# Save effects_to_add
	if "effects_to_add" in current_res:
		var new_effects: Array[status_effect_chance] = []
		for st in status_effects:
			if status_add_checks.has(st) and status_add_checks[st].button_pressed:
				var sec := status_effect_chance.new()
				if "status" in sec: sec.status = st
				
				var chance_val: float = active_status_chances.get(st, 100.0)
				if "chance" in sec: sec.chance = chance_val / 100.0
				new_effects.append(sec)
		
		current_res.effects_to_add.assign(new_effects)

	# Save effects_to_remove
	if "effects_to_remove" in current_res:
		var remove_effects: Array[status_effect] = []
		for st in status_effects:
			if status_remove_checks.has(st) and status_remove_checks[st].button_pressed:
				remove_effects.append(st)
		
		current_res.effects_to_remove.assign(remove_effects)

	if "custom_icon" in current_res:
		icon_preview.texture = icon_preview.texture

	if "stat_requirement" in current_res:
		if not current_res.stat_requirement:
			current_res.stat_requirement = rpg_stats.new()

		for stat_name in stat_req_edits.keys():
			if stat_name is String and stat_req_edits[stat_name] is SpinBox:
				current_res.stat_requirement.set(stat_name, int(stat_req_edits[stat_name].value))


func _on_save_pressed() -> void:
	if not current_res:
		return

	_apply_form_to_resource()

	var target_dir := SKILL_DIR
	var chosen_elem = current_res.skill_element if "skill_element" in current_res else (current_res.element if "element" in current_res else null)

	if chosen_elem and "name" in chosen_elem and chosen_elem.name != "":
		var folder_name := _sanitize_filename(chosen_elem.name)
		target_dir = SKILL_DIR.path_join(folder_name)

	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	var file_name := current_path.get_file()
	var desired_path := target_dir.path_join(file_name)

	if desired_path != current_path:
		if FileAccess.file_exists(desired_path):
			DirAccess.remove_absolute(desired_path)

		var old_path := current_path
		var rename_err := DirAccess.rename_absolute(old_path, desired_path)
		
		if rename_err == OK:
			current_path = desired_path
		else:
			current_path = desired_path
			if FileAccess.file_exists(old_path):
				DirAccess.remove_absolute(old_path)

	var err := ResourceSaver.save(current_res, current_path)
	if err == OK:
		dirty = false
		save_button.disabled = true
		revert_button.disabled = true
		var sk_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
		status_label.text = "Saved '" + sk_name + "' to disk."
		_load_all_skills()
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
	var sk_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	status_label.text = "Reverted '" + sk_name + "'"
