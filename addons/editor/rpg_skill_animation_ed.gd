@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is Control
