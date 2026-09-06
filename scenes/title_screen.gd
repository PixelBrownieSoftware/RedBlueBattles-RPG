extends Node2D

@onready var slots_container: VBoxContainer = %SlotsContainer
var delete_confirm_dialog: ConfirmationDialog
var pending_delete_slot: int = -1

func _ready() -> void:
	_setup_confirm_dialog()
	refresh_slots()
	await FadeScene.fade_bg(Color(Color.BLACK, 0), 0.5)

func _setup_confirm_dialog() -> void:
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "Delete Save Slot?"
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)

func refresh_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	for slot_idx in range(5):
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 8)

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(400, 48)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Overlay RichTextLabel inside Button to support BBCode colors
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.anchor_right = 1.0
		rtl.anchor_bottom = 1.0
		rtl.offset_left = 10
		rtl.offset_top = 10
		rtl.offset_right = -10
		rtl.offset_bottom = -10
		rtl.fit_content = true

		var exists := SaveSystem.save_exists(slot_idx)

		if exists:
			var summary := SaveSystem.get_slot_summary(slot_idx)
			var party: Array = summary.get("party", [])

			var text_str := "[b]Slot %d:[/b] " % (slot_idx + 1)
			if party.is_empty():
				text_str += "No Party Data"
			else:
				var party_parts := []
				for member in party:
					var m_name: String = member.get("name", "Unit")
					var m_lvl: int = member.get("level", 1)
					var m_col: String = member.get("color_html", "ffffff")
					party_parts.append("[color=#%s]%s[/color] (Lv %d)" % [m_col, m_name, m_lvl])
				text_str += " | ".join(party_parts)

			rtl.text = text_str
			slot_btn.pressed.connect(func(): _on_slot_clicked(slot_idx, true))
		else:
			rtl.text = "[b]Slot %d:[/b] [color=gray]Empty - New Game[/color]" % (slot_idx + 1)
			slot_btn.pressed.connect(func(): _on_slot_clicked(slot_idx, false))

		slot_btn.add_child(rtl)
		slot_row.add_child(slot_btn)

		var delete_btn := Button.new()
		delete_btn.text = "Delete"
		delete_btn.custom_minimum_size = Vector2(80, 48)
		delete_btn.disabled = not exists
		delete_btn.pressed.connect(func(): _prompt_delete_slot(slot_idx))
		slot_row.add_child(delete_btn)

		slots_container.add_child(slot_row)

func _on_slot_clicked(slot_idx: int, is_load: bool) -> void:
	_disable_all_buttons()

	if is_load:
		GlobalVariables.current_slot_index = slot_idx
		SaveSystem.load_game(slot_idx)
	else:
		GlobalVariables.current_slot_index = slot_idx

	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file("res://scenes/overworld_scene.tscn")

func _prompt_delete_slot(slot_idx: int) -> void:
	pending_delete_slot = slot_idx
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete Save Slot %d?" % (slot_idx + 1)
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if pending_delete_slot != -1:
		SaveSystem.delete_slot(pending_delete_slot)
		pending_delete_slot = -1
		refresh_slots()

func _disable_all_buttons() -> void:
	for row in slots_container.get_children():
		for btn in row.get_children():
			if btn is Button:
				btn.disabled = true
