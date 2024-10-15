extends Panel

@export var stat_description : stats_name.STATS
@export var elemental_desc : RichTextLabel
@export var base_desc : RichTextLabel
@export var stat_name : RichTextLabel
@export var stat_texture : TextureRect
var str_texture : Texture2D = preload("res://sprites/GUI/gui_str.png")
var vit_texture : Texture2D = preload("res://sprites/GUI/gui_vit.png")
var mag_texture : Texture2D = preload("res://sprites/GUI/gui_mag.png")
var dex_texture : Texture2D = preload("res://sprites/GUI/gui_dex.png")
var ag_texture : Texture2D = preload("res://sprites/GUI/gui_ag.png")
var luc_texture : Texture2D = preload("res://sprites/GUI/gui_luc.png")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	stat_name.text = GlobalVariables.stat_colour(stat_description)
	match stat_description:
		stats_name.STATS.STRENGTH:
			stat_texture.texture = str_texture
			base_desc.text = "Determines the power of physicals."
		stats_name.STATS.VITALITY:
			stat_texture.texture = vit_texture
			base_desc.text = "Reduces damage from attacks."
		stats_name.STATS.DEXTERITY:
			stat_texture.texture = dex_texture
			base_desc.text = "Determines accuracy of attacks."
		stats_name.STATS.MAGIC:
			stat_texture.texture = mag_texture
			base_desc.text = "Determines the power of magic."
		stats_name.STATS.AGILITY:
			stat_texture.texture = ag_texture
			base_desc.text = "Determines evasion of attacks."
		stats_name.STATS.LUCK:
			stat_texture.texture = luc_texture
			base_desc.text = "Determines how likely you are to score a LUCKY hit."
	var role = {}
	var large : Array[String]
	var medium : Array[String]
	var small : Array[String]
	role["Large"] = null
	role["Medium"] = null
	role["Small"] = null
	for el in GlobalVariables.element_lookup:
		if el == "None":
			continue
		var stats : rpg_stats_increase = GlobalVariables.element_lookup[el].stats
		var element_string : String = "[color=" +GlobalVariables.element_lookup[el].colour.to_html() + "]" + el + "[/color]" 
		var stats_number : float
		match stat_description:
			stats_name.STATS.STRENGTH:
				stats_number = stats.strength
			stats_name.STATS.VITALITY:
				stats_number = stats.vitality
			stats_name.STATS.DEXTERITY:
				stats_number = stats.dexterity
			stats_name.STATS.MAGIC:
				stats_number = stats.magic_pow
			stats_name.STATS.AGILITY:
				stats_number = stats.agility
			stats_name.STATS.LUCK:
				stats_number = stats.luck
		if stats_number > 0.6:
			large.append(element_string)
		else: if stats_number < 0.6 && stats_number > 0.25:
			medium.append(element_string)
		else: if stats_number < 0.25 && stats_number > 0:
			small.append(element_string)
			 
	role["Large"] = large
	role["Medium"] = medium
	role["Small"] = small
	for key in role:
		if role[key].size() == 0:
			continue
		elemental_desc.text += key + " role:\n"
		for el in role[key]:
			elemental_desc.text += el + ", "
		elemental_desc.text += "\n"
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
