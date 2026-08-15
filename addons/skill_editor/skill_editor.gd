# res://addons/skill_editor/skill_editor.gd
@tool
extends Control

const SKILL_DIR := "res://data/skills"
const ELEMENT_DIR := "res://data/elements"
const STATUS_DIR := "res://data/status_effects"
const STAT_ICON_DIR := "res://sprites/GUI/stats/"

@onready var element_filter_select: OptionButton = %ElementFilterSelect
@onready var search_bar: LineEdit = %SearchBar
@onready var refresh_button: Button = %RefreshButton
@onready var new_skill_button: Button = %NewSkillButton
@onready var skill_list: ItemList = %SkillList

@onready var save_button: Button = %SaveButton
@onready var revert_button: Button = %RevertButton
@onready var status_label: Label = %StatusLabel
@onready var form_root: VBoxContainer = %FormRoot

var current_path : String = ""
var current_res : rpg_skill = null
var elements : Array = []        # Array of loaded element resources
var status_effects : Array = []  # Array of loaded status_effect resources
var loaded_skills : Array = []   # Array of { "path": String, "res": rpg_skill }

# Form Controls
var name_edit : LineEdit
var learnable_check : CheckBox
var usable_anyone_check : CheckBox
var power_edit : SpinBox
var stamina_cost_edit : SpinBox
var repeat_min_edit : SpinBox
var repeat_max_edit : SpinBox
var scope_select : OptionButton
var element_select : OptionButton

var icon_preview : TextureRect
var file_dialog : EditorFileDialog

var stat_req_edits : Dictionary = {}           # String "strength" -> SpinBox
var status_enable_checks : Dictionary = {}     # status_effect resource -> CheckBox
var status_rows : Dictionary = {}              # status_effect resource -> Control
var status_active_vbox : VBoxContainer         # Container for active/selected status cards
var active_status_sliders : Dictionary = {}    # status_effect resource -> HSlider
var active_status_labels : Dictionary = {}     # status_effect resource -> Label
var active_status_chances : Dictionary = {}    # status_effect resource -> float (0.0 - 100.0)

var elemental_status_label : RichTextLabel
var status_search_edit : LineEdit

var dirty : bool = false
var suppress_signals : bool = false


func _ready() -> void:
	if not is_instance_valid(skill_list):
		return

	_setup_file_dialog()

	refresh_button.pressed.connect(_refresh_all)
	search_bar.text_changed.connect(func(_q): _filter_and_populate_list())
	element_filter_select.item_selected.connect(func(_idx): _filter_and_populate_list())
	skill_list.item_selected.connect(_on_skill_selected)
	new_skill_button.pressed.connect(_on_new_skill_pressed)

	save_button.pressed.connect(_on_save_pressed)
	revert_button.pressed.connect(_on_revert_pressed)

	_set_form_enabled(false)
	call_deferred("_refresh_all")


func _refresh_all() -> void:
	_ensure_directories_exist()
	_load_elements()
	_load_status_effects()
	_build_form()
	_populate_element_filter_dropdown()
	_load_all_skills()
	_filter_and_populate_list()

	if current_path != "":
		_load_skill(current_path)


func _ensure_directories_exist() -> void:
	for dir_path in [SKILL_DIR, ELEMENT_DIR, STATUS_DIR]:
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


func _load_all_skills() -> void:
	loaded_skills.clear()
	var paths := _find_resources_recursive(SKILL_DIR)
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

	form_root.add_child(_hsep())

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

	# ---- Elemental Status Inflict Readout ----
	form_root.add_child(_section_header("Elemental Status Inflict (Inherited from Element)"))
	elemental_status_label = RichTextLabel.new()
	elemental_status_label.bbcode_enabled = true
	elemental_status_label.fit_content = true
	elemental_status_label.custom_minimum_size = Vector2(0, 24)
	form_root.add_child(_labeled_row("Element Inflicts", elemental_status_label))

	form_root.add_child(_hsep())

	# ---- Skill Status Inflict Configurator ----
	form_root.add_child(_section_header("Skill Status Inflict (effects_to_add)"))

	var active_hdr := Label.new()
	active_hdr.text = "Active Status Effects (Adjust Chance 0% - 100%):"
	form_root.add_child(active_hdr)

	status_active_vbox = VBoxContainer.new()
	status_active_vbox.add_theme_constant_override("separation", 6)
	form_root.add_child(status_active_vbox)

	form_root.add_child(HSeparator.new())

	status_search_edit = LineEdit.new()
	status_search_edit.placeholder_text = "Search status effects to toggle..."
	status_search_edit.clear_button_enabled = true
	status_search_edit.text_changed.connect(_on_status_search_changed)
	form_root.add_child(_labeled_row("Filter Statuses", status_search_edit))

	var status_scroll := ScrollContainer.new()
	status_scroll.custom_minimum_size = Vector2(0, 180)
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var status_vbox := VBoxContainer.new()
	status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_vbox.add_theme_constant_override("separation", 4)

	status_rows.clear()
	status_enable_checks.clear()

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
		status_enable_checks[st] = enable_cb
		row.add_child(enable_cb)

		if "icon" in st and st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		status_rows[st] = row
		status_vbox.add_child(row)

	status_scroll.add_child(status_vbox)
	form_root.add_child(status_scroll)

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
		if status_enable_checks.has(st):
			status_enable_checks[st].button_pressed = false
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


func _on_status_search_changed(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for st in status_rows.keys():
		var row: Control = status_rows[st]
		var st_name: String = st.name if "name" in st else ""
		if filter == "" or st_name.to_lower().contains(filter):
			row.visible = true
		else:
			row.visible = false


func _on_element_changed(_idx: int) -> void:
	_update_elemental_status_display()
	_on_field_changed()


func _update_elemental_status_display() -> void:
	if element_select.selected >= 0 and element_select.get_item_count() > 0 and element_select.selected < elements.size():
		var chosen_el = elements[element_select.selected]
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
	_set_container_editable(form_root, enabled)


func _set_container_editable(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit or child is HSlider:
			child.editable = enabled
		elif child is Button or child is ColorPickerButton or child is CheckBox or child is OptionButton:
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


func _load_skill(path: String) -> void:
	current_path = path
	current_res = load(path)
	_populate_form()
	_set_form_enabled(true)
	dirty = false
	save_button.disabled = true
	revert_button.disabled = true
	var sk_name: String = current_res.name if ("name" in current_res and current_res.name != "") else current_path.get_file()
	status_label.text = "Editing: " + sk_name


func _populate_form() -> void:
	suppress_signals = true

	if "name" in current_res: name_edit.text = current_res.name
	if "learnable" in current_res: learnable_check.button_pressed = current_res.learnable
	if "usable_by_anyone" in current_res: usable_anyone_check.button_pressed = current_res.usable_by_anyone
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

	if status_search_edit:
		status_search_edit.text = ""
		_on_status_search_changed("")

	active_status_sliders.clear()
	active_status_labels.clear()
	active_status_chances.clear()
	for c in status_active_vbox.get_children():
		c.queue_free()

	for st in status_effects:
		var has_status := false
		var status_chance := 100.0
		if "effects_to_add" in current_res and current_res.effects_to_add:
			for sec in current_res.effects_to_add:
				if sec and "status" in sec and (sec.status == st or (sec.status and "name" in sec.status and "name" in st and sec.status.name == st.name)):
					has_status = true
					if "chance" in sec: status_chance = sec.chance * 100.0
					break

		if status_enable_checks.has(st):
			status_enable_checks[st].button_pressed = has_status

		if has_status:
			_toggle_status_active(st, true, status_chance)

	if "custom_icon" in current_res:
		icon_preview.texture = current_res.custom_icon

	if "stat_requirement" in current_res and current_res.stat_requirement:
		for stat_name in stat_req_edits.keys():
			if stat_name is String and stat_req_edits.has(stat_name):
				stat_req_edits[stat_name].value = current_res.stat_requirement.get(stat_name)

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

	# FIXED: Assign elements into typed array using assign() to avoid Variant Array crashes
	if "effects_to_add" in current_res:
		var new_effects: Array[status_effect_chance] = []
		for st in status_effects:
			if status_enable_checks.has(st) and status_enable_checks[st].button_pressed:
				var sec := status_effect_chance.new()
				if "status" in sec: sec.status = st
				
				var chance_val: float = active_status_chances.get(st, 100.0)
				if "chance" in sec: sec.chance = chance_val / 100.0
				new_effects.append(sec)
		
		current_res.effects_to_add.assign(new_effects)

	if "custom_icon" in current_res:
		current_res.custom_icon = icon_preview.texture

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

	# Relocate file to folder based on assigned element
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
			var count := 1
			var base_name := file_name.get_basename()
			while FileAccess.file_exists(target_dir.path_join(base_name + "_" + str(count) + ".tres")):
				count += 1
			desired_path = target_dir.path_join(base_name + "_" + str(count) + ".tres")

		var rename_err := DirAccess.rename_absolute(current_path, desired_path)
		if rename_err == OK:
			current_path = desired_path

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
