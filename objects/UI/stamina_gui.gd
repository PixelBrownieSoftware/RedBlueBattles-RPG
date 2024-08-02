extends HBoxContainer
var stamina_gui: Texture2D = preload("res://sprites/stamina_gui.png")
var stamina_gui_empty : Texture2D= preload("res://sprites/stamina_gui_empty.png")

func render_stamina(current, max):
	for i in get_children().size():
		var st : TextureRect = get_child(i) as TextureRect
		if i >= max:
			st.texture = null
		else:if i > current:
			st.texture = stamina_gui_empty
		else:if i <= current:
			st.texture = stamina_gui
			
func render_points(current):
	render_stamina(current, current)
	
func render_stamina_max(current, max):
	for i in get_children().size():
		var st : TextureRect = get_child(i) as TextureRect
		if i >= max:
			st.texture = null
		else:if i > current:
			st.texture = stamina_gui_empty
		else:if i <= current:
			st.texture = stamina_gui
