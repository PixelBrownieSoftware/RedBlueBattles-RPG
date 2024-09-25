extends TabBar
var status_desc_box = preload("res://objects/UI/status_effect_description_box.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for stat in GlobalVariables.status_effect_lookup:
		var el_box = status_desc_box.instantiate()
		el_box.status = GlobalVariables.status_effect_lookup[stat]
		el_box.populate()
		$ScrollContainer/VBoxContainer.add_child(el_box)
