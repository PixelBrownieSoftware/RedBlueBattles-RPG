# res://addons/character_stats_editor/plugin.gd
@tool
extends EditorPlugin

const MainPanel = preload("res://addons/character_stats_editor/character_stats_editor.tscn")

var main_panel_instance: Control


func _enter_tree() -> void:
	main_panel_instance = MainPanel.instantiate()
	
	# Add the main screen control to Godot's editor main screen container
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	
	# Hide it by default until selected
	_make_visible(false)


func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		main_panel_instance.visible = visible


func _get_plugin_name() -> String:
	return "Char Stats"


func _get_plugin_icon() -> Texture2D:
	# Uses standard Godot editor icon for user scripts/tools
	return get_editor_interface().get_base_control().get_theme_icon("Script", "EditorIcons")
