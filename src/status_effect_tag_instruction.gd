extends Resource
class_name status_effect_tag_instruction
enum STATUS_TAG_INSTRUCTION {
	REPLACE,
	CANCEL_OUT,
	BLOCKED_BY
}
@export var instruction_type : STATUS_TAG_INSTRUCTION 
@export var status_effect_inflict_id : int
@export var status_effect_affect_id : int
