# res://addons/battle_flow_editor/battle_flow_editor.gd
@tool
extends Control

var graph_edit : GraphEdit
var refresh_button : Button
var layout_button : Button
var active_nodes : Dictionary = {} # Path (String) -> BattleGraphNode
var battle_flow_tab : Control

const BattleNodeScript = preload("res://addons/battle_flow_editor/battle_node.gd")

func _enter_tree():
	# The scene now nests this tool's UI under Tabs/Battle Flow, alongside a
	# Character Editor tab. Fall back to self if an older scene is loaded.
	battle_flow_tab = get_node_or_null("Tabs/Battle Flow")
	if not battle_flow_tab:
		battle_flow_tab = self

	# Clean up any existing children to prevent duplicates when reloading
	for child in battle_flow_tab.get_children():
		child.queue_free()

	# Create UI Container layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_flow_tab.add_child(vbox)
	
	# Header Button Bar
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	refresh_button = Button.new()
	refresh_button.text = "Refresh Graph"
	hbox.add_child(refresh_button)
	
	layout_button = Button.new()
	layout_button.text = "Auto-Layout Nodes"
	hbox.add_child(layout_button)
	
	# Graph Edit Workspace
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.minimap_enabled = true
	vbox.add_child(graph_edit)
	
	# Connect Signals
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	refresh_button.pressed.connect(load_campaign_graph)
	layout_button.pressed.connect(trigger_auto_layout)
	
	# Load initial state
	call_deferred("load_campaign_graph")

func load_campaign_graph():
	if not graph_edit:
		return
		
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	active_nodes.clear()
	
	var dir_path = "res://data/levels/" 
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
		
	var all_file_paths = find_resources_recursive(dir_path)
	
	var unpositioned_nodes_found = false
	
	for full_path in all_file_paths:
		var res = load(full_path)
		if res is battle_level_group:
			var node = GraphNode.new()
			node.set_script(BattleNodeScript)
			graph_edit.add_child(node)
			
			node.setup(full_path, res)
			node.dragged.connect(node._on_dragged)
			active_nodes[full_path] = node
			
			# Check if we need to auto-layout because they are all at (0,0)
			if res.editor_position == Vector2.ZERO:
				unpositioned_nodes_found = true
			
	call_deferred("populate_connections")
	
	# If we found brand-new levels sitting at (0,0), auto-organize them immediately
	if unpositioned_nodes_found:
		call_deferred("trigger_auto_layout")

func populate_connections():
	for from_path in active_nodes:
		var from_node = active_nodes[from_path]
		
		# 1. Connect Unlock paths (Port 0)
		for to_res in from_node.level_group.battle_groups_unlock:
			if to_res:
				var to_node = find_node_by_resource(to_res)
				if to_node:
					graph_edit.connect_node(from_node.name, 0, to_node.name, 0)
					
		# 2. Connect Remove paths (Port 1)
		for to_res in from_node.level_group.battle_groups_remove:
			if to_res:
				var to_node = find_node_by_resource(to_res)
				if to_node:
					graph_edit.connect_node(from_node.name, 1, to_node.name, 0)

func find_node_by_resource(res: battle_level_group) -> GraphNode:
	for path in active_nodes:
		if active_nodes[path].level_group == res:
			return active_nodes[path]
	return null

# Recursive helper function to scan folders
func find_resources_recursive(path: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var sub_folder_path = path.path_join(file_name)
					results.append_array(find_resources_recursive(sub_folder_path))
			else:
				if file_name.ends_with(".tres"):
					results.append(path.path_join(file_name))
					
			file_name = dir.get_next()
		dir.list_dir_end()
		
	return results

# --- AUTO-LAYOUT ENGINE ---
func trigger_auto_layout():
	if active_nodes.is_empty():
		return
		
	var parent_map : Dictionary = {} # child_res -> Array of parent_res
	
	# Populate parent relationships to identify "Root" nodes (no parents)
	for path in active_nodes:
		var node = active_nodes[path]
		var res = node.level_group
		
		var connections = res.battle_groups_unlock + res.battle_groups_remove
		for target in connections:
			if target:
				if not parent_map.has(target):
					parent_map[target] = []
				parent_map[target].append(res)
				
	# Find root nodes (any level group that is not in parent_map)
	var roots : Array[battle_level_group] = []
	for path in active_nodes:
		var res = active_nodes[path].level_group
		if not parent_map.has(res):
			roots.append(res)
			
	# Fallback: if there's a circular graph with no root, just grab the first node
	if roots.is_empty():
		roots.append(active_nodes.values()[0].level_group)
		
	var depths : Dictionary = {} # res -> int (Column index)
	var queue : Array = []
	
	# Initialize roots at Column 0
	for root in roots:
		depths[root] = 0
		queue.append(root)
		
	# Breadth-First Search (BFS) to calculate column depth levels
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = depths[current]
		
		var next_connections = current.battle_groups_unlock + current.battle_groups_remove
		for child in next_connections:
			if child:
				# Push child further to the right if there is a deeper pathway to it
				if not depths.has(child) or depths[child] < current_depth + 1:
					depths[child] = current_depth + 1
					if not queue.has(child):
						queue.append(child)
						
	# Group our resources by column index
	var columns : Dictionary = {} # int (Column) -> Array[battle_level_group]
	for res in depths:
		var col = depths[res]
		if not columns.has(col):
			columns[col] = []
		columns[col].append(res)
		
	# Layout Spacing Configuration
	var x_spacing : float = 380.0
	var y_spacing : float = 200.0
	var offset_margin : Vector2 = Vector2(100.0, 100.0)
	
	# Apply final calculated grid positions
	for col in columns:
		var column_nodes = columns[col]
		var total_height = (column_nodes.size() - 1) * y_spacing
		
		for row in range(column_nodes.size()):
			var res = column_nodes[row]
			var node = find_node_by_resource(res)
			if node:
				var x_pos = offset_margin.x + (col * x_spacing)
				var y_pos = offset_margin.y + (row * y_spacing) - (total_height / 2.0) + 250.0
				
				var target_pos = Vector2(x_pos, max(50.0, y_pos))
				node.position_offset = target_pos
				
				# Write the new position back to the resource
				res.editor_position = target_pos
				ResourceSaver.save(res, node.resource_path)

# --- Standard Signal Handlers ---
func _on_connection_request(from_node_name: StringName, from_port: int, to_node_name: StringName, to_port: int):
	var from_node = graph_edit.get_node(NodePath(from_node_name))
	var to_node = graph_edit.get_node(NodePath(to_node_name))
	
	if from_node && to_node:
		if from_port == 0: # UNLOCK
			if not from_node.level_group.battle_groups_unlock.has(to_node.level_group):
				from_node.level_group.battle_groups_unlock.append(to_node.level_group)
				ResourceSaver.save(from_node.level_group, from_node.resource_path)
				graph_edit.connect_node(from_node_name, from_port, to_node_name, to_port)
		elif from_port == 1: # REMOVE
			if not from_node.level_group.battle_groups_remove.has(to_node.level_group):
				from_node.level_group.battle_groups_remove.append(to_node.level_group)
				ResourceSaver.save(from_node.level_group, from_node.resource_path)
				graph_edit.connect_node(from_node_name, from_port, to_node_name, to_port)

func _on_disconnection_request(from_node_name: StringName, from_port: int, to_node_name: StringName, to_port: int):
	var from_node = graph_edit.get_node(NodePath(from_node_name))
	var to_node = graph_edit.get_node(NodePath(to_node_name))
	
	if from_node && to_node:
		if from_port == 0:
			from_node.level_group.battle_groups_unlock.erase(to_node.level_group)
		elif from_port == 1:
			from_node.level_group.battle_groups_remove.erase(to_node.level_group)
			
		ResourceSaver.save(from_node.level_group, from_node.resource_path)
		graph_edit.disconnect_node(from_node_name, from_port, to_node_name, to_port)
