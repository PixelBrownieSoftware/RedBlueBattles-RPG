# res://addons/battle_tester/battle_tester.gd
@tool
extends Control

const CHAR_DIR := "res://data/characters"
const SKILL_DIR := "res://data/skills"
const STATUS_DIR := "res://data/status_effects"
const GROUP_DIR := "res://data/battle_groups"
const ELEMENT_DIR := "res://data/elements"

# Dynamic node getters (prevents null instance & unique name missing errors in editor)
var calculate_button: Button:
	get: return _find_node_by_name(self, "CalculateButton") as Button
var refresh_button: Button:
	get: return _find_node_by_name(self, "RefreshButton") as Button
var max_level_spin: SpinBox:
	get: return _find_node_by_name(self, "MaxLevelSpin") as SpinBox

var atk_stats_label: RichTextLabel:
	get: return _find_node_by_name(self, "AtkStatsLabel") as RichTextLabel
var skill_stats_label: RichTextLabel:
	get: return _find_node_by_name(self, "SkillStatsLabel") as RichTextLabel
var def_stats_label: RichTextLabel:
	get: return _find_node_by_name(self, "DefStatsLabel") as RichTextLabel
var damage_label: RichTextLabel:
	get: return _find_node_by_name(self, "DamageLabel") as RichTextLabel

var attacker_select: OptionButton:
	get: return _find_node_by_name(self, "AttackerSelect") as OptionButton
var attacker_level_slider: HSlider:
	get: return _find_node_by_name(self, "AttackerLevelSlider") as HSlider
var attacker_lvl_label: Label:
	get: return _find_node_by_name(self, "AttackerLvlLabel") as Label
var attacker_status_search: LineEdit:
	get: return _find_node_by_name(self, "AttackerStatusSearch") as LineEdit
var attacker_status_vbox: VBoxContainer:
	get: return _find_node_by_name(self, "AttackerStatusVBox") as VBoxContainer
var attacker_active_status_vbox: VBoxContainer:
	get: return _find_node_by_name(self, "AttackerActiveVBox") as VBoxContainer

var skill_search: LineEdit:
	get: return _find_node_by_name(self, "SkillSearch") as LineEdit
var skill_vbox: VBoxContainer:
	get: return _find_node_by_name(self, "SkillVBox") as VBoxContainer

var defender_select: OptionButton:
	get: return _find_node_by_name(self, "DefenderSelect") as OptionButton
var defender_level_slider: HSlider:
	get: return _find_node_by_name(self, "DefenderLevelSlider") as HSlider
var defender_lvl_label: Label:
	get: return _find_node_by_name(self, "DefenderLvlLabel") as Label
var defender_status_search: LineEdit:
	get: return _find_node_by_name(self, "DefenderStatusSearch") as LineEdit
var defender_status_vbox: VBoxContainer:
	get: return _find_node_by_name(self, "DefenderStatusVBox") as VBoxContainer
var defender_active_status_vbox: VBoxContainer:
	get: return _find_node_by_name(self, "DefenderActiveVBox") as VBoxContainer

# Attacker & Defender Character Search Controls
var attacker_char_search: LineEdit
var defender_char_search: LineEdit

# Skill Element Filter
var skill_element_filter: OptionButton

# Group Import UI Controls
var import_group_button: Button
var group_import_dialog: ConfirmationDialog
var group_search_input: LineEdit
var side_option_button: OptionButton
var group_member_item_list: ItemList
var loaded_group_members: Array[Dictionary] = []

# Loaded Data Arrays
var characters: Array = []
var skills: Array = []
var status_effects: Array = []
var elements: Array = []

# Selection State
var selected_skill: rpg_skill = null
var skill_radio_buttons: Dictionary = {}

var attacker_status_checks: Dictionary = {}
var attacker_status_rows: Dictionary = {}

var defender_status_checks: Dictionary = {}
var defender_status_rows: Dictionary = {}

var skill_rows: Dictionary = {}


func _find_node_by_name(parent: Node, target_name: String) -> Node:
	if not is_instance_valid(parent):
		return null
	if parent.name == target_name:
		return parent
	for child in parent.get_children():
		var res := _find_node_by_name(child, target_name)
		if res:
			return res
	return null


func _ready() -> void:
	if not is_instance_valid(calculate_button):
		return

	_setup_character_search_ui()
	_setup_skill_element_filter_ui()
	_setup_group_import_ui()

	if is_instance_valid(refresh_button):
		refresh_button.pressed.connect(_load_all_data)
	if is_instance_valid(calculate_button):
		calculate_button.pressed.connect(_calculate_damage)
	if is_instance_valid(max_level_spin):
		max_level_spin.value_changed.connect(_on_max_level_changed)

	if is_instance_valid(attacker_level_slider):
		attacker_level_slider.value_changed.connect(func(v): if is_instance_valid(attacker_lvl_label): attacker_lvl_label.text = "Lvl: %d" % int(v))
	if is_instance_valid(defender_level_slider):
		defender_level_slider.value_changed.connect(func(v): if is_instance_valid(defender_lvl_label): defender_lvl_label.text = "Lvl: %d" % int(v))

	if is_instance_valid(attacker_status_search):
		attacker_status_search.text_changed.connect(func(q): _filter_statuses(q, attacker_status_rows))
	if is_instance_valid(defender_status_search):
		defender_status_search.text_changed.connect(func(q): _filter_statuses(q, defender_status_rows))

	if is_instance_valid(max_level_spin):
		_on_max_level_changed(max_level_spin.value)
		
	_load_all_data()


func _setup_skill_element_filter_ui() -> void:
	var sk_s := skill_search
	if not is_instance_valid(sk_s):
		return

	var sk_parent := sk_s.get_parent()
	if not is_instance_valid(sk_parent):
		return

	var sk_idx := sk_s.get_index()

	var filter_hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Element:"
	filter_hbox.add_child(lbl)

	skill_element_filter = OptionButton.new()
	skill_element_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_element_filter.item_selected.connect(func(_idx): _filter_skills(sk_s.text))
	filter_hbox.add_child(skill_element_filter)

	sk_parent.add_child(filter_hbox)
	sk_parent.move_child(filter_hbox, sk_idx + 1)
	sk_s.text_changed.connect(func(q): _filter_skills(q))


func _setup_character_search_ui() -> void:
	var atk_sel := attacker_select
	if is_instance_valid(atk_sel):
		var atk_parent := atk_sel.get_parent()
		var atk_idx := atk_sel.get_index()

		attacker_char_search = LineEdit.new()
		attacker_char_search.placeholder_text = "🔍 Search Attacker..."
		attacker_char_search.clear_button_enabled = true
		attacker_char_search.text_changed.connect(func(q): _filter_character_dropdown(atk_sel, q))
		atk_parent.add_child(attacker_char_search)
		atk_parent.move_child(attacker_char_search, atk_idx)

	var def_sel := defender_select
	if is_instance_valid(def_sel):
		var def_parent := def_sel.get_parent()
		var def_idx := def_sel.get_index()

		defender_char_search = LineEdit.new()
		defender_char_search.placeholder_text = "🔍 Search Defender..."
		defender_char_search.clear_button_enabled = true
		defender_char_search.text_changed.connect(func(q): _filter_character_dropdown(def_sel, q))
		def_parent.add_child(defender_char_search)
		def_parent.move_child(defender_char_search, def_idx)


func _filter_character_dropdown(opt_btn: OptionButton, query: String) -> void:
	if not is_instance_valid(opt_btn):
		return

	var currently_selected_char: battle_character_base = null
	if opt_btn.selected >= 0 and opt_btn.selected < opt_btn.item_count:
		var meta = opt_btn.get_item_metadata(opt_btn.selected)
		if meta is battle_character_base:
			currently_selected_char = meta

	opt_btn.clear()
	var filter := query.strip_edges().to_lower()

	var match_idx := 0
	var added_count := 0

	for idx in range(characters.size()):
		var c: battle_character_base = characters[idx]
		var c_name := c.name if c.name != "" else "Unnamed Character"

		if filter == "" or c_name.to_lower().contains(filter):
			opt_btn.add_item(c_name, added_count)
			opt_btn.set_item_metadata(added_count, c)

			if currently_selected_char and c == currently_selected_char:
				match_idx = added_count

			added_count += 1

	if opt_btn.item_count > 0:
		opt_btn.select(match_idx)


func _setup_group_import_ui() -> void:
	var ref_btn := refresh_button
	if not is_instance_valid(ref_btn):
		return

	var toolbar := ref_btn.get_parent()

	import_group_button = Button.new()
	import_group_button.text = "Import Enemy from Group..."
	import_group_button.pressed.connect(_on_open_group_import_dialog)
	toolbar.add_child(import_group_button)
	toolbar.move_child(import_group_button, 1)

	group_import_dialog = ConfirmationDialog.new()
	group_import_dialog.title = "Select Enemy Character from Group"
	group_import_dialog.size = Vector2i(450, 350)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)

	var side_hbox := HBoxContainer.new()
	var side_lbl := Label.new()
	side_lbl.text = "Load Character into Target Side:"
	side_hbox.add_child(side_lbl)

	side_option_button = OptionButton.new()
	side_option_button.add_item("Defender (Right Side)", 0)
	side_option_button.add_item("Attacker (Left Side)", 1)
	side_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_hbox.add_child(side_option_button)
	main_vbox.add_child(side_hbox)

	group_search_input = LineEdit.new()
	group_search_input.placeholder_text = "Search up characters or groups..."
	group_search_input.text_changed.connect(_filter_group_members_list)
	main_vbox.add_child(group_search_input)

	group_member_item_list = ItemList.new()
	group_member_item_list.custom_minimum_size = Vector2(0, 200)
	group_member_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(group_member_item_list)

	group_import_dialog.add_child(main_vbox)
	group_import_dialog.confirmed.connect(_confirm_import_group_character)
	add_child(group_import_dialog)


func _on_open_group_import_dialog() -> void:
	_scan_and_load_groups()
	_filter_group_members_list(group_search_input.text)
	group_import_dialog.popup_centered()


func _scan_and_load_groups() -> void:
	loaded_group_members.clear()
	var search_paths := [GROUP_DIR, "res://data/"]
	var scanned_paths: Array[String] = []

	for search_dir in search_paths:
		if DirAccess.dir_exists_absolute(search_dir):
			var paths := _find_resources_recursive(search_dir)
			for p in paths:
				if scanned_paths.has(p):
					continue
				scanned_paths.append(p)

				var res = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
				if res is battle_group_data:
					_extract_members_from_group(res, p.get_file().get_basename())
				elif res is battle_level_group and "battle_groups" in res and res.battle_groups:
					var level_group_name: String = res.name if res.name != "" else p.get_file().get_basename()
					for bg_idx in range(res.battle_groups.size()):
						var bg: battle_group_data = res.battle_groups[bg_idx]
						if bg:
							var group_title := level_group_name + " (Group " + str(bg_idx + 1) + ")"
							_extract_members_from_group(bg, group_title)


func _extract_members_from_group(group: battle_group_data, source_title: String) -> void:
	if not group.opponents:
		return

	for member in group.opponents:
		if member and member.character:
			var char_base: battle_character_base = member.character
			var char_name: String = char_base.name if char_base.name != "" else "Unnamed Character"

			var min_lvl: int = member.min_level
			var max_lvl: int = member.max_level
			var lvl_str := "Lvl %d" % min_lvl if min_lvl == max_lvl else "Lvl %d-%d" % [min_lvl, max_lvl]

			var display_text := "👤 %s [%s] — (Battle Group: %s)" % [char_name, lvl_str, source_title]

			loaded_group_members.append({
				"char": char_base,
				"min_lvl": min_lvl,
				"max_lvl": max_lvl,
				"display": display_text
			})


func _filter_group_members_list(query: String) -> void:
	group_member_item_list.clear()
	var filter := query.strip_edges().to_lower()

	for idx in range(loaded_group_members.size()):
		var item := loaded_group_members[idx]
		if filter == "" or item.display.to_lower().contains(filter):
			var list_idx := group_member_item_list.add_item(item.display)
			group_member_item_list.set_item_metadata(list_idx, item)

	if group_member_item_list.item_count > 0:
		group_member_item_list.select(0)


func _confirm_import_group_character() -> void:
	var selected_items := group_member_item_list.get_selected_items()
	if selected_items.is_empty():
		return

	var item_data: Dictionary = group_member_item_list.get_item_metadata(selected_items[0])
	var char_res: battle_character_base = item_data.char
	var target_lvl: int = item_data.max_lvl
	var load_to_attacker := (side_option_button.selected == 1)

	if not characters.has(char_res):
		characters.append(char_res)

	var spin := max_level_spin
	if is_instance_valid(spin) and target_lvl > spin.value:
		spin.value = target_lvl
		_on_max_level_changed(target_lvl)

	if load_to_attacker:
		if is_instance_valid(attacker_char_search):
			attacker_char_search.text = ""
		var atk_sel := attacker_select
		_filter_character_dropdown(atk_sel, "")
		_select_character_in_dropdown(atk_sel, char_res)
		if is_instance_valid(attacker_level_slider): attacker_level_slider.value = target_lvl
		if is_instance_valid(attacker_lvl_label): attacker_lvl_label.text = "Lvl: %d" % target_lvl
	else:
		if is_instance_valid(defender_char_search):
			defender_char_search.text = ""
		var def_sel := defender_select
		_filter_character_dropdown(def_sel, "")
		_select_character_in_dropdown(def_sel, char_res)
		if is_instance_valid(defender_level_slider): defender_level_slider.value = target_lvl
		if is_instance_valid(defender_lvl_label): defender_lvl_label.text = "Lvl: %d" % target_lvl


func _select_character_in_dropdown(opt_btn: OptionButton, char_res: battle_character_base) -> void:
	if not is_instance_valid(opt_btn):
		return
	for i in range(opt_btn.item_count):
		var meta = opt_btn.get_item_metadata(i)
		if meta == char_res or (meta is battle_character_base and meta.name == char_res.name):
			opt_btn.select(i)
			return


func _on_max_level_changed(new_max: float) -> void:
	var m_val := maxf(10.0, new_max)
	if is_instance_valid(attacker_level_slider):
		attacker_level_slider.max_value = m_val
	if is_instance_valid(defender_level_slider):
		defender_level_slider.max_value = m_val


func _load_all_data() -> void:
	_load_elements()
	_load_characters()
	_load_skills()
	_load_status_effects()
	_populate_ui()


func _load_elements() -> void:
	elements.clear()
	var paths := _find_resources_recursive(ELEMENT_DIR)
	for path in paths:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res and ("name" in res or "element_name" in res):
			elements.append(res)
	elements.sort_custom(func(a, b): 
		var a_name: String = a.name if "name" in a else ""
		var b_name: String = b.name if "name" in b else ""
		return a_name < b_name
	)


func _load_characters() -> void:
	characters.clear()
	var paths := _find_resources_recursive(CHAR_DIR)
	for path in paths:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res is battle_character_base:
			characters.append(res)
	characters.sort_custom(func(a, b): return a.name < b.name)


func _load_skills() -> void:
	skills.clear()
	var paths := _find_resources_recursive(SKILL_DIR)
	for path in paths:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res is rpg_skill:
			skills.append(res)
	skills.sort_custom(func(a, b): return a.name < b.name)


func _load_status_effects() -> void:
	status_effects.clear()
	var paths := _find_resources_recursive(STATUS_DIR)
	for path in paths:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res is status_effect:
			status_effects.append(res)
	status_effects.sort_custom(func(a, b): return a.name < b.name)


func _populate_ui() -> void:
	if is_instance_valid(attacker_char_search):
		attacker_char_search.text = ""
	if is_instance_valid(defender_char_search):
		defender_char_search.text = ""

	var atk_sel := attacker_select
	var def_sel := defender_select

	_filter_character_dropdown(atk_sel, "")
	_filter_character_dropdown(def_sel, "")

	if is_instance_valid(def_sel) and def_sel.item_count > 1:
		def_sel.select(1)

	if is_instance_valid(skill_element_filter):
		skill_element_filter.clear()
		skill_element_filter.add_item("All Elements", 0)
		skill_element_filter.set_item_metadata(0, null)

		for idx in range(elements.size()):
			var el = elements[idx]
			var item_idx := idx + 1
			var el_name: String = el.name if "name" in el else "Element " + str(item_idx)
			skill_element_filter.add_item(el_name, item_idx)
			skill_element_filter.set_item_metadata(item_idx, el)

	if is_instance_valid(attacker_status_vbox) and is_instance_valid(attacker_active_status_vbox):
		_build_status_list(attacker_status_vbox, attacker_status_checks, attacker_status_rows, attacker_active_status_vbox)
	if is_instance_valid(defender_status_vbox) and is_instance_valid(defender_active_status_vbox):
		_build_status_list(defender_status_vbox, defender_status_checks, defender_status_rows, defender_active_status_vbox)
	
	if is_instance_valid(skill_vbox):
		_build_skills_list()


func _build_status_list(vbox: VBoxContainer, check_dict: Dictionary, row_dict: Dictionary, active_vbox: VBoxContainer) -> void:
	for c in vbox.get_children():
		c.queue_free()

	check_dict.clear()
	row_dict.clear()

	for st in status_effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var cb := CheckBox.new()
		cb.text = st.name
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(pressed: bool):
			_update_active_status_card(st, pressed, active_vbox)
		)
		check_dict[st] = cb
		row.add_child(cb)

		if st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		row_dict[st] = row
		vbox.add_child(row)


func _update_active_status_card(st: status_effect, is_active: bool, active_vbox: VBoxContainer) -> void:
	if not is_instance_valid(active_vbox):
		return

	var existing_card: Control = null
	for child in active_vbox.get_children():
		if child.has_meta("status_ref") and child.get_meta("status_ref") == st:
			existing_card = child
			break

	if is_active:
		if existing_card:
			return

		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.3, 0.22, 0.9)
		style.border_color = Color(0.4, 0.8, 0.45, 1.0)
		style.set_border_width_all(1)
		style.set_content_margin_all(4)
		card.add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		if st.icon:
			var tr := TextureRect.new()
			tr.texture = st.icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(18, 18)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		var lbl := Label.new()
		lbl.text = st.name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var remove_btn := Button.new()
		remove_btn.text = " Remove "
		remove_btn.pressed.connect(func():
			_uncheck_status(st)
			if is_instance_valid(card):
				card.queue_free()
		)
		row.add_child(remove_btn)

		card.add_child(row)
		card.set_meta("status_ref", st)
		active_vbox.add_child(card)
	else:
		if existing_card:
			existing_card.queue_free()


func _uncheck_status(st: status_effect) -> void:
	if attacker_status_checks.has(st) and is_instance_valid(attacker_status_checks[st]):
		attacker_status_checks[st].button_pressed = false
	if defender_status_checks.has(st) and is_instance_valid(defender_status_checks[st]):
		defender_status_checks[st].button_pressed = false


func _get_element_color(el) -> Color:
	if not el:
		return Color.WHITE
	if "colour" in el and el.colour is Color:
		return el.colour
	if "color" in el and el.color is Color:
		return el.color
	return Color.WHITE


func _build_skills_list() -> void:
	var sk_v := skill_vbox
	if not is_instance_valid(sk_v):
		return

	for c in sk_v.get_children():
		c.queue_free()

	skill_rows.clear()
	skill_radio_buttons.clear()

	var button_group := ButtonGroup.new()

	for sk in skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var sk_elem = sk.skill_element if "skill_element" in sk else (sk.element if "element" in sk else null)
		var elem_color := _get_element_color(sk_elem)

		var radio := CheckBox.new()
		radio.button_group = button_group
		radio.text = sk.name
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radio.add_theme_color_override("font_color", elem_color)
		radio.add_theme_color_override("font_pressed_color", elem_color)
		radio.add_theme_color_override("font_hover_color", elem_color.lightened(0.2))

		radio.toggled.connect(func(pressed):
			if pressed:
				selected_skill = sk
		)
		skill_radio_buttons[sk] = radio
		row.add_child(radio)

		var icon_tex: Texture2D = sk.get("custom_icon") if sk.get("custom_icon") != null else sk.get("icon")
		if icon_tex:
			var tr := TextureRect.new()
			tr.texture = icon_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		var pwr_lbl := Label.new()
		pwr_lbl.text = "Pwr: " + str(sk.power)
		pwr_lbl.add_theme_color_override("font_color", elem_color)
		row.add_child(pwr_lbl)

		skill_rows[sk] = row
		sk_v.add_child(row)

	if skills.size() > 0:
		skill_radio_buttons[skills[0]].button_pressed = true
		selected_skill = skills[0]


func _filter_statuses(query: String, row_dict: Dictionary) -> void:
	var filter := query.strip_edges().to_lower()
	for st in row_dict.keys():
		var row: HBoxContainer = row_dict[st]
		if is_instance_valid(row):
			row.visible = (filter == "" or st.name.to_lower().contains(filter))


func _filter_skills(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	var selected_elem_idx := skill_element_filter.selected if is_instance_valid(skill_element_filter) else 0

	var filter_element = null
	if selected_elem_idx > 0 and selected_elem_idx < skill_element_filter.get_item_count():
		filter_element = skill_element_filter.get_item_metadata(selected_elem_idx)

	for sk in skill_rows.keys():
		var row: HBoxContainer = skill_rows[sk]
		if not is_instance_valid(row):
			continue
		var sk_name: String = sk.name if sk.name != "" else ""
		var matches_text := (filter == "" or sk_name.to_lower().contains(filter))

		var sk_elem = sk.skill_element if "skill_element" in sk else (sk.element if "element" in sk else null)
		var matches_element = (filter_element == null or sk_elem == filter_element)

		row.visible = (matches_text and matches_element)

# ---- Combat Calculation Engine ----
func _calculate_damage() -> void:
	var atk_sel := attacker_select
	var def_sel := defender_select
	var dmg_lbl := damage_label

	if not is_instance_valid(atk_sel) or not is_instance_valid(def_sel):
		return

	if atk_sel.selected < 0 or def_sel.selected < 0:
		if is_instance_valid(dmg_lbl):
			dmg_lbl.text = "[center][color=red]Error: Please select both an Attacker and a Defender.[/color][/center]"
		return

	if not selected_skill:
		if is_instance_valid(dmg_lbl):
			dmg_lbl.text = "[center][color=red]Error: Please select an attacking skill.[/color][/center]"
		return

	var attacker_base: battle_character_base = atk_sel.get_item_metadata(atk_sel.selected)
	var defender_base: battle_character_base = def_sel.get_item_metadata(def_sel.selected)

	if not attacker_base or not defender_base:
		if is_instance_valid(dmg_lbl):
			dmg_lbl.text = "[center][color=red]Error: Invalid character selection.[/color][/center]"
		return

	var attacker_lvl := int(attacker_level_slider.value) if is_instance_valid(attacker_level_slider) else 1
	var defender_lvl := int(defender_level_slider.value) if is_instance_valid(defender_level_slider) else 1

	var attacker_node := battle_character_data.new()
	attacker_node.name = "Attacker_" + attacker_base.name
	add_child(attacker_node)
	attacker_node.new_data(attacker_base, attacker_lvl)

	var defender_node := battle_character_data.new()
	defender_node.name = "Defender_" + defender_base.name
	add_child(defender_node)
	defender_node.new_data(defender_base, defender_lvl)

	var atk_applied_effects: Array[status_effect_chance] = []
	for st in status_effects:
		if attacker_status_checks.has(st) and attacker_status_checks[st].button_pressed:
			var sec := status_effect_chance.new()
			sec.status = st
			sec.chance = 1.0
			atk_applied_effects.append(sec)
	attacker_node.apply_status_effects(atk_applied_effects)

	var def_applied_effects: Array[status_effect_chance] = []
	for st in status_effects:
		if defender_status_checks.has(st) and defender_status_checks[st].button_pressed:
			var sec := status_effect_chance.new()
			sec.status = st
			sec.chance = 1.0
			def_applied_effects.append(sec)
	defender_node.apply_status_effects(def_applied_effects)

	var pot_mods: Dictionary = attacker_node.get_element_potential_modifiers(selected_skill)

	var hit_chance: float = attacker_node.calculate_chance(attacker_node.dexterity_net, defender_node.agility_net, 0.95)
	var hit_percentage_str: String = "%.1f%%" % (hit_chance * 100.0)
	var hit_color: Color = Color.RED.lerp(Color.GREEN, hit_chance)
	var hit_hex_color: String = hit_color.to_html(false)

	# --- FIXED METHOD CHECK HERE ---
	var attack_result: int = 0
	if selected_skill.has_method("damage_formula"):
		attack_result = selected_skill.damage_formula(attacker_node, defender_node)
	elif selected_skill.has_method("process_damage"):
		attack_result = selected_skill.process_damage(attacker_node, defender_node)
	elif "power" in selected_skill:
		attack_result = selected_skill.power

	var per_hit_dmg: int = attack_result
	var lucky_bonus: float = GlobalVariables.lucky_damage_bonus if "lucky_damage_bonus" in GlobalVariables else 1.5
	var per_hit_dmg_luc: int = int(float(per_hit_dmg) * lucky_bonus)

	var hit_min: int = selected_skill.repeat_min if "repeat_min" in selected_skill else 1
	var hit_max: int = selected_skill.repeat_max if "repeat_max" in selected_skill else 1
	var total_min_dmg: int = per_hit_dmg * hit_min
	var total_max_dmg: int = per_hit_dmg * hit_max
	var total_min_dmg_luc: int = per_hit_dmg_luc * hit_min
	var total_max_dmg_luc: int = per_hit_dmg_luc * hit_max

	var sk_elem = selected_skill.skill_element if "skill_element" in selected_skill else (selected_skill.element if "element" in selected_skill else null)
	var el_name : String= sk_elem.name if sk_elem else "None"
	var net_affinity := defender_node.get_elemental_affinity(sk_elem) if sk_elem and defender_node.has_method("get_elemental_affinity") else 1.0

	# 1. Attacker Visual Card
	var atk_lbl := atk_stats_label
	if is_instance_valid(atk_lbl):
		var atk_txt := "[b]Name:[/b] [color=cyan]%s[/color] (Lvl %d)\n" % [attacker_base.name, attacker_lvl]
		atk_txt += "[b]HP:[/b] [color=green]%d / %d[/color]\n\n" % [attacker_node.health, attacker_node.max_health]
		atk_txt += "[b]Net Stats:[/b]\n"
		atk_txt += "• STR: %d  | VIT: %d  | MAG: %d\n" % [attacker_node.strength_net, attacker_node.vitality_net, attacker_node.magic_pow_net]
		atk_txt += "• DEX: %d  | AGI: %d  | LUC: %d" % [attacker_node.dexterity_net, attacker_node.agility_net, attacker_node.luck_net]
		atk_lbl.text = atk_txt

	# 2. Skill & Combat Card
	var sk_lbl := skill_stats_label
	if is_instance_valid(sk_lbl):
		var elem_color := _get_element_color(sk_elem)
		var elem_hex := elem_color.to_html(false)

		var sk_txt := "[b]Skill:[/b] [color=#%s]%s[/color]\n" % [elem_hex, selected_skill.name]
		sk_txt += "[b]Power:[/b] %d  |  [b]Hits:[/b] %d-%d\n" % [selected_skill.power, hit_min, hit_max]
		sk_txt += "[b]Element:[/b] [color=#%s]%s[/color]\n" % [elem_hex, el_name]
		sk_txt += "[b]Potential Mod:[/b] [color=cyan]x%.2f[/color]\n" % (pot_mods["damage_multipler"] if pot_mods.has("damage_multipler") else 1.0)
		sk_txt += "[b]Accuracy:[/b] [color=#%s][b]%s[/b][/color]" % [hit_hex_color, hit_percentage_str]
		sk_lbl.text = sk_txt

	# 3. Defender Visual Card
	var def_lbl := def_stats_label
	if is_instance_valid(def_lbl):
		var def_txt := "[b]Name:[/b] [color=orange]%s[/color] (Lvl %d)\n" % [defender_base.name, defender_lvl]
		def_txt += "[b]HP:[/b] [color=green]%d / %d[/color]\n\n" % [defender_node.health, defender_node.max_health]
		def_txt += "[b]Net Stats & Resistance:[/b]\n"
		def_txt += "• STR: %d  | VIT: %d  | MAG: %d\n" % [defender_node.strength_net, defender_node.vitality_net, defender_node.magic_pow_net]
		def_txt += "• DEX: %d  | AGI: %d  | LUC: %d\n" % [defender_node.dexterity_net, defender_node.agility_net, defender_node.luck_net]
		def_txt += "• %s Affinity: [color=yellow]x%.2f[/color]" % [el_name, net_affinity]
		def_lbl.text = def_txt

	# 4. Highlighted Damage Banner
	if is_instance_valid(dmg_lbl):
		if hit_min == hit_max:
			dmg_lbl.text = "[center][font_size=20][b]TOTAL DAMAGE: [color=lime]%d HP[/color]   |   LUCKY CRIT: [color=gold]%d HP[/color][/b][/font_size][/center]" % [total_min_dmg, total_min_dmg_luc]
		else:
			dmg_lbl.text = "[center][font_size=20][b]DAMAGE RANGE (%d-%d Hits): [color=lime]%d - %d HP[/color]   |   LUCKY RANGE: [color=gold]%d - %d HP[/color][/b][/font_size][/center]" % [hit_min, hit_max, total_min_dmg, total_max_dmg, total_min_dmg_luc, total_max_dmg_luc]

	attacker_node.queue_free()
	defender_node.queue_free()
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
