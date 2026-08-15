# res://addons/battle_flow_editor/plugin.gd
@tool
extends EditorPlugin

# Instantiate the scene directly so its node structure (Tabs, Character Editor, etc.) is used.
const FlowEditorScene = preload("res://addons/battle_flow_editor/battle_flow_editor.tscn")
var editor_instance: Control

func _enter_tree():
	editor_instance = FlowEditorScene.instantiate()

	# Force the UI to expand and fill the entire editor workspace
	editor_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add it to Godot's main screen (the top tab bar)
	get_editor_interface().get_editor_main_screen().add_child(editor_instance)

	# Hide it initially
	_make_visible(false)

func _exit_tree():
	# Clean up the node when the plugin is disabled
	if editor_instance:
		editor_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool):
	if editor_instance:
		editor_instance.visible = visible

func _get_plugin_name() -> String:
	return "Battle Campaign Flow"
