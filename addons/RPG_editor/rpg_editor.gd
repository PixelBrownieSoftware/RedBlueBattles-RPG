@tool
extends Control

@onready var tab_container: TabContainer = %TabContainer

const CHAR_SCENE = preload("res://addons/character_stats_editor/character_stats_editor.tscn")
const ELEM_SCENE = preload("res://addons/element_editor/element_editor.tscn")
const SKILL_SCENE = preload("res://addons/skill_editor/skill_editor.tscn")
const STATUS_SCENE = preload("res://addons/status_effect_editor/status_effect_editor.tscn")
const GROUP_SCENE = preload("res://addons/battle_group_editor/battle_group_editor.tscn")
const LEVEL_GROUP_SCENE = preload("res://addons/level_group_editor/level_group_editor.tscn")
const TESTER_SCENE = preload("res://addons/battle_tester/battle_tester.tscn")


func _ready() -> void:
	if not is_instance_valid(tab_container):
		return

	# Programmatic setup if tabs don't exist in scene tree
	if tab_container.get_child_count() == 0:
		_add_tab("Characters", CHAR_SCENE)
		_add_tab("Elements", ELEM_SCENE)
		_add_tab("Skills", SKILL_SCENE)
		_add_tab("Status Effects", STATUS_SCENE)
		_add_tab("Battle Groups", GROUP_SCENE)
		_add_tab("Level Groups", LEVEL_GROUP_SCENE)
		_add_tab("Battle Tester", TESTER_SCENE)

	if not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)


func _add_tab(tab_name: String, scene: PackedScene) -> void:
	var instance = scene.instantiate()
	instance.name = tab_name
	tab_container.add_child(instance)


func _on_tab_changed(tab_idx: int) -> void:
	var active_child := tab_container.get_child(tab_idx)
	if not active_child:
		return

	if active_child.has_method("_refresh_all"):
		active_child._refresh_all()

	if active_child.has_method("_load_all_data"):
		active_child._load_all_data()

	if active_child.has_method("_load_elements"):
		active_child._load_elements()

	if active_child.has_method("_load_status_effects"):
		active_child._load_status_effects()

	if active_child.has_method("_load_all_reference_data"):
		active_child._load_all_reference_data()

	if active_child.has_method("_filter_and_populate_groups"):
		active_child._filter_and_populate_groups()

	if active_child.has_method("_filter_and_populate_levels"):
		active_child._filter_and_populate_levels()
