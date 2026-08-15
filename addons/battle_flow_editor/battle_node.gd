# res://addons/battle_flow_editor/battle_node.gd
@tool
extends GraphNode
class_name BattleGraphNode

var resource_path : String
var level_group : battle_level_group

func setup(res_path: String, res: battle_level_group):
	resource_path = res_path
	level_group = res
	title = res.name if res.name != "" else res_path.get_file().get_basename()
	position_offset = res.editor_position
	
	# Apply background color properties 
	self.self_modulate = res.colour_BG
	
	# Wipe old slots safely
	for child in get_children():
		child.queue_free()
	
	# Row 1: Left Input (Port 0) | Right Output 0 (Unlock - Green)
	var row1 = HBoxContainer.new()
	var label_in = Label.new()
	label_in.text = "In "
	var label_out_unlock = Label.new()
	label_out_unlock.text = " -> Unlock"
	label_out_unlock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_out_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row1.add_child(label_in)
	row1.add_child(label_out_unlock)
	add_child(row1)
	
	# Row 2: No Input | Right Output 1 (Remove - Red)
	var row2 = HBoxContainer.new()
	var label_out_remove = Label.new()
	label_out_remove.text = " -> Lock Out"
	label_out_remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_out_remove.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row2.add_child(label_out_remove)
	add_child(row2)

	# Row 3: Metadata display
	var type_str = "NORMAL"
	match res.type_battle:
		0: type_str = "BOSS"
		2: type_str = "MINI_BOSS"
		3: type_str = "HARD"
	var label_info = Label.new()
	label_info.text = "Type: %s | Fights: %d" % [type_str, res.battle_groups.size()]
	label_info.modulate = Color(0.7, 0.7, 0.7)
	add_child(label_info)

	# Set up slot properties
	# Slot index 0 (Row 1): Input Left enabled, Output Right enabled (Color Green)
	set_slot_enabled_left(0, true)
	set_slot_type_left(0, 0)
	set_slot_color_left(0, Color.ALICE_BLUE)
	
	set_slot_enabled_right(0, true)
	set_slot_type_right(0, 0)
	set_slot_color_right(0, Color.MEDIUM_SPRING_GREEN)

	# Slot index 1 (Row 2): Input Left disabled, Output Right enabled (Color Red)
	set_slot_enabled_left(1, false)
	set_slot_enabled_right(1, true)
	set_slot_type_right(1, 1)
	set_slot_color_right(1, Color.CRIMSON)

func _on_dragged(from: Vector2, to: Vector2):
	if level_group:
		level_group.editor_position = to
		ResourceSaver.save(level_group, resource_path)

## res://addons/battle_flow_editor/battle_node.gd
#@tool
#extends GraphNode
#class_name BattleGraphNode
#
#var resource_path : String
#var level_group : battle_level_group
#
#func setup(res_path: String, res: battle_level_group):
	#resource_path = res_path
	#level_group = res
	#title = res.name if res.name else res_path.get_file().get_basename()
	#position_offset = res.editor_position
	#
	## Match node visual header to the designer's selected BG color!
	#self.self_modulate = res.colour_BG
	#
	## Clear old slots
	#for child in get_children():
		#child.queue_free()
	#
	## Define Ports:
	## Slot 0 (Row 1): Left Input (Port 0 - Blue) | Right Output (Port 0 - Green for Unlock)
	#set_slot(0, true, 0, Color.ALICE_BLUE, true, 0, Color.MEDIUM_SPRING_GREEN)
	#var label_unlock = Label.new()
	#label_unlock.text = "--> Unlocks Level"
	#add_child(label_unlock)
	#
	## Slot 1 (Row 2): No Left Input | Right Output (Port 1 - Red for Remove)
	#set_slot(1, false, 0, Color.BLACK, true, 1, Color.CRIMSON)
	#var label_remove = Label.new()
	#label_remove.text = "--> Removes Level"
	#label_remove.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	#add_child(label_remove)
#
	## Extra Info Label
	#var info_label = Label.new()
	#var type_str = "NORMAL"
	#match res.type_battle:
		#0: type_str = "BOSS"
		#2: type_str = "MINI_BOSS"
		#3: type_str = "HARD"
	#info_label.text = "Type: %s | Fights: %d" % [type_str, res.battle_groups.size()]
	#info_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	#add_child(info_label)
#
#func _on_dragged(from: Vector2, to: Vector2):
	#if level_group:
		#level_group.editor_position = to
		#ResourceSaver.save(level_group, resource_path)
