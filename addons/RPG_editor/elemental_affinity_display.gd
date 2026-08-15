# res://addons/RPG_editor/elemental_affinity_display.gd
@tool
extends Control
class_name ElementalAffinityDisplay

const ELEMENT_DIR := "res://data/elements"

## Signal emitted when any affinity slider value is changed by the user
signal affinity_changed(element_name: String, new_value: float)

## X = Min limit, Y = Max limit (e.g. Vector2(-1.0, 2.0))
@export var upper_lower_limit: Vector2 = Vector2(-1.0, 2.0):
	set(value):
		upper_lower_limit = value
		_update_slider_limits()

## Default starting value (e.g. 1.0 for Characters, 0.0 for Status Effects)
@export var default_value: float = 1.0:
	set(value):
		default_value = value
		_update_defaults()

@export var icon_size: Vector2 = Vector2(20, 20)
@export var label_width: float = 120.0
@export var list_min_height: float = 180.0:
	set(value):
		list_min_height = value
		_update_min_size()

@export var is_editable: bool = true:
	set(value):
		is_editable = value
		_update_editability()

var elements: Array = [] # Stores loaded `element` resources
var sliders: Dictionary = {} # element_name -> HSlider
var spinboxes: Dictionary = {} # element_name -> SpinBox
var rows: Dictionary = {} # element_name -> HBoxContainer

var scroll_container: ScrollContainer
var main_container: VBoxContainer


func _ready() -> void:
	_setup_container()
	_load_elements()
	_build_display()


func _update_min_size() -> void:
	custom_minimum_size = Vector2(0, list_min_height)
	if is_instance_valid(scroll_container):
		scroll_container.custom_minimum_size = Vector2(0, list_min_height)


func _setup_container() -> void:
	for child in get_children():
		child.queue_free()

	_update_min_size()

	# Outer ScrollContainer
	scroll_container = ScrollContainer.new()
	scroll_container.name = "AffinityScrollContainer"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.custom_minimum_size = Vector2(0, list_min_height)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll_container)

	# Inner VBoxContainer
	main_container = VBoxContainer.new()
	main_container.name = "AffinityVBoxContainer"
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 6)
	scroll_container.add_child(main_container)


func _load_elements() -> void:
	elements.clear()
	var paths := _find_resources_recursive(ELEMENT_DIR)
	for path in paths:
		var res = load(path)
		if res is element and res.name.to_lower() != "none":
			elements.append(res)
	elements.sort_custom(func(a, b): return a.name < b.name)


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


func _build_display() -> void:
	sliders.clear()
	spinboxes.clear()
	rows.clear()

	for el in elements:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		# 1. Element Name
		var name_lbl := Label.new()
		name_lbl.text = el.name
		name_lbl.custom_minimum_size = Vector2(label_width, 0)
		row.add_child(name_lbl)

		# 2. Icon (if available)
		var icon: Texture2D = el.icon
		if icon != null:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = icon_size
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)

		# 3. Horizontal Slider
		var slider := HSlider.new()
		slider.min_value = upper_lower_limit.x
		slider.max_value = upper_lower_limit.y
		slider.step = 0.25
		slider.tick_count = int((upper_lower_limit.y - upper_lower_limit.x) / 0.25) + 1
		slider.ticks_on_borders = true
		slider.value = default_value
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.editable = is_editable
		
		# Prevent mouse wheel from hijacking scroll
		slider.focus_mode = Control.FOCUS_NONE
		slider.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				slider.accept_event()
		)

		sliders[el.name] = slider
		row.add_child(slider)

		# 4. SpinBox Readout
		var spin := SpinBox.new()
		spin.min_value = upper_lower_limit.x
		spin.max_value = upper_lower_limit.y
		spin.step = 0.25
		spin.value = default_value
		spin.custom_minimum_size = Vector2(80, 0)
		spin.editable = is_editable

		# Prevent mouse wheel from hijacking scroll
		spin.focus_mode = Control.FOCUS_NONE
		spin.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				spin.accept_event()
		)

		spinboxes[el.name] = spin
		row.add_child(spin)

		# Sync Slider <-> SpinBox
		var el_name: String = el.name
		slider.value_changed.connect(func(val: float):
			if not is_equal_approx(spin.value, val):
				spin.value = val
			affinity_changed.emit(el_name, val)
		)
		spin.value_changed.connect(func(val: float):
			if not is_equal_approx(slider.value, val):
				slider.value = val
		)

		rows[el.name] = row
		main_container.add_child(row)


func _update_slider_limits() -> void:
	for el_name in sliders.keys():
		if is_instance_valid(sliders[el_name]):
			sliders[el_name].min_value = upper_lower_limit.x
			sliders[el_name].max_value = upper_lower_limit.y
			sliders[el_name].tick_count = int((upper_lower_limit.y - upper_lower_limit.x) / 0.25) + 1
		if is_instance_valid(spinboxes[el_name]):
			spinboxes[el_name].min_value = upper_lower_limit.x
			spinboxes[el_name].max_value = upper_lower_limit.y


func _update_defaults() -> void:
	for el_name in sliders.keys():
		if is_instance_valid(sliders[el_name]):
			sliders[el_name].value = default_value
		if is_instance_valid(spinboxes[el_name]):
			spinboxes[el_name].value = default_value


## Set displayed values from an Array[elemental_affinity] or Dictionary
func display_affinities(affinity_data) -> void:
	for el_name in sliders.keys():
		if is_instance_valid(sliders[el_name]):
			sliders[el_name].value = default_value
		if is_instance_valid(spinboxes[el_name]):
			spinboxes[el_name].value = default_value

	if affinity_data == null:
		return

	if affinity_data is Array:
		for entry in affinity_data:
			if entry and "elementalName" in entry and sliders.has(str(entry.elementalName)):
				var el_key := str(entry.elementalName)
				var val: float = float(entry.affinity) if ("affinity" in entry and entry.affinity != null) else default_value
				if is_instance_valid(sliders[el_key]):
					sliders[el_key].value = val
				if is_instance_valid(spinboxes[el_key]):
					spinboxes[el_key].value = val
					
	elif affinity_data is Dictionary:
		for el_key in affinity_data.keys():
			var key_str := str(el_key)
			if sliders.has(key_str):
				var raw_val = affinity_data[el_key]
				var val: float = float(raw_val) if raw_val != null else default_value
				if is_instance_valid(sliders[key_str]):
					sliders[key_str].value = val
				if is_instance_valid(spinboxes[key_str]):
					spinboxes[key_str].value = val

## Returns a Dictionary mapping element names to their current slider values
func get_affinities() -> Dictionary:
	var result := {}
	for el_name in sliders.keys():
		result[el_name] = sliders[el_name].value
	return result


func _update_editability() -> void:
	for el_name in sliders.keys():
		if is_instance_valid(sliders[el_name]):
			sliders[el_name].editable = is_editable
		if is_instance_valid(spinboxes[el_name]):
			spinboxes[el_name].editable = is_editable
