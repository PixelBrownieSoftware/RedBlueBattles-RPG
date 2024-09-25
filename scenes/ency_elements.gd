extends TabBar
var elemental_desc_box = preload("res://objects/UI/element_description_box.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for stat in GlobalVariables.element_lookup:
		if stat == "None":
			continue
		var el_box = elemental_desc_box.instantiate()
		el_box.elemental = GlobalVariables.element_lookup[stat]
		el_box.populate()
		$ScrollContainer/VBoxContainer.add_child(el_box)
