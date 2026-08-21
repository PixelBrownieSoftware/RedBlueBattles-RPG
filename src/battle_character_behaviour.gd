# res://data/behaviours/battle_character_behaviour.gd
@tool
extends Resource
class_name battle_character_behaviour

@export var is_NOT : bool = false
@export var condition : BEHAVIOUR_CONDITION
@export var compare : NUMBER_COMP
@export_range(0,1,0.01) var percentage: float 
@export_range(-2,2,0.01) var elemental: float 
@export var exact_number: int
@export_range(0.0,1.0) var execution_chance : float

@export var subject: SUBJECT
@export var skill_condition: SKILL_CONDITION
@export var target_condition: TARGET_CONDITION

# For specific skill/element/status
@export var specific_skill: rpg_skill
@export var specific_element: element
@export var specific_status: status_effect

enum SUBJECT {
	TARGET,
	TARGET_INVERSE,
	SKILL,
	TURN,
	ROUND,
	EVERY_X_ROUND
}

enum SKILL_CONDITION {
	SPECIFIC,
	ELEMENT,
	POWER,
	STATUS
}

enum TARGET_CONDITION {
	HEALTH,
	STAMINA,
	STATUS_EFFECT,
	ELEMENTAL_AFFINITY,
	STATUS_MODIFY_AFFINITY
}

enum BEHAVIOUR_CONDITION {
	TARGET_HP,
	ELEMENTAL_AFFINITY,
	ALWAYS,
	TURN_ROUNDS_ELAPSED
}

enum NUMBER_COMP {
	EQUAL,
	LESS,
	LESS_EQUAL,
	GREATER,
	GREATER_EQUAL
}

func check_cond(character: battle_character_data, target: battle_character_data, skill: rpg_skill, turn_number: int, round_number: int) -> bool:
	"""
	Check if this behaviour condition is met (taking is_NOT into account)
	"""
	var result := false
	
	match subject:
		SUBJECT.TARGET:
			result = check_target(target, skill)
		
		SUBJECT.TARGET_INVERSE:
			# If checking enemy, check ally instead
			result = check_target(character, skill)
		
		SUBJECT.SKILL:
			print("Skill: "+ skill.name)
			result = check_skill(skill)
		
		SUBJECT.TURN:
			result = compare_numbers(turn_number, exact_number)
		
		SUBJECT.EVERY_X_ROUND:
			result = (round_number % exact_number == 0) #if exact_number != 0 else false
		
		SUBJECT.ROUND:
			result = compare_numbers(round_number, exact_number)

	return !result if is_NOT else result


func check_target(target: battle_character_data, skill: rpg_skill) -> bool:
	"""Check target based on TARGET_CONDITION"""
	
	match target_condition:
		TARGET_CONDITION.HEALTH:
			var target_hp = target.health
			var threshold = target.max_health * percentage
			return compare_numbers(int(target_hp), int(threshold))
		
		TARGET_CONDITION.STAMINA:
			var target_stamina = target.stamina
			var threshold = target.max_stamina * percentage
			return compare_numbers(int(target_stamina), int(threshold))
		
		TARGET_CONDITION.STATUS_EFFECT:
			if specific_status == null:
				return false
			return target.has_status(specific_status)
		
		TARGET_CONDITION.ELEMENTAL_AFFINITY:
			# If no specific element, use skill's element
			var check_element = specific_element if specific_element != null else (skill.skill_element if skill else null)
			
			if check_element == null:
				return false
			
			var affinity = target.get_elemental_affinity(check_element)
			return compare_numbers(int(affinity * 100), int(elemental * 100))
		
		TARGET_CONDITION.STATUS_MODIFY_AFFINITY:
			return check_affinity_after_status(target, skill)
	
	return false


func check_affinity_after_status(target: battle_character_data, skill: rpg_skill) -> bool:
	"""
	Predict target's elemental affinity after status effects are applied
	Returns true if ANY predicted affinity meets the condition
	"""
	
	if skill == null:
		return false
	
	var status_effects = skill.get_all_status_effects()
	
	if status_effects.is_empty():
		return false
	
	var predicted_affinities = {}
	
	for el in GlobalVariables.element_lookup:
		predicted_affinities[el] = target.get_elemental_affinity(GlobalVariables.get_element(el))
	
	for status in status_effects:
		for affinity_change in status.elemental_affinity_change:
			var element = GlobalVariables.get_element(affinity_change.elementalName)
			if element != null:
				predicted_affinities[affinity_change.elementalName] += affinity_change.affinity
	
	for element in predicted_affinities:
		var predicted = predicted_affinities[element]
		
		if compare_numbers(int(predicted * 100), int(elemental * 100)):
			return true
	
	return false


func check_skill(skill: rpg_skill) -> bool:
	"""Check skill based on SKILL_CONDITION"""
	
	if skill == null:
		return false
	
	match skill_condition:
		SKILL_CONDITION.SPECIFIC:
			return skill == specific_skill
		
		SKILL_CONDITION.ELEMENT:
			if specific_element == null:
				return false
			return skill.skill_element == specific_element
		
		SKILL_CONDITION.POWER:
			return compare_numbers(int(skill.power), exact_number)
		
		SKILL_CONDITION.STATUS:
			if specific_status == null:
				return false
			for status in skill.get_all_status_effects():
				if status == specific_status:
					return true
			return false
	
	return false


func compare_numbers(actual: int, expected: int) -> bool:
	"""Compare two numbers based on NUMBER_COMP"""
	
	match compare:
		NUMBER_COMP.EQUAL:
			return actual == expected
		NUMBER_COMP.LESS:
			return actual < expected
		NUMBER_COMP.LESS_EQUAL:
			return actual <= expected
		NUMBER_COMP.GREATER:
			return actual > expected
		NUMBER_COMP.GREATER_EQUAL:
			return actual >= expected
	
	return false


func get_description() -> String:
	"""Human-readable description of this condition"""
	
	var subject_str = SUBJECT.keys()[subject]
	var condition_str = ""
	var not_prefix = "NOT " if is_NOT else ""
	
	match subject:
		SUBJECT.TARGET, SUBJECT.TARGET_INVERSE:
			match target_condition:
				TARGET_CONDITION.HEALTH:
					condition_str = "HP %s %.0f%%" % [NUMBER_COMP.keys()[compare], percentage * 100]
				TARGET_CONDITION.STAMINA:
					condition_str = "Stamina %s %.0f%%" % [NUMBER_COMP.keys()[compare], percentage * 100]
				TARGET_CONDITION.STATUS_EFFECT:
					condition_str = "Has %s" % (specific_status.status_name if specific_status else "status")
				TARGET_CONDITION.ELEMENTAL_AFFINITY:
					var elem_name = specific_element.element_name if specific_element else "Skill element"
					condition_str = "%s affinity %s %.1f" % [elem_name, NUMBER_COMP.keys()[compare], elemental]
				TARGET_CONDITION.STATUS_MODIFY_AFFINITY:
					condition_str = "After status: affinity %s %.1f" % [NUMBER_COMP.keys()[compare], elemental]
		
		SUBJECT.SKILL:
			match skill_condition:
				SKILL_CONDITION.SPECIFIC:
					condition_str = "Specific: %s" % (specific_skill.name if specific_skill else "?")
				SKILL_CONDITION.ELEMENT:
					condition_str = "Element: %s" % (specific_element.name if specific_element else "?")
				SKILL_CONDITION.POWER:
					condition_str = "Power %s %d" % [NUMBER_COMP.keys()[compare], exact_number]
				SKILL_CONDITION.STATUS:
					condition_str = "Applies: %s" % (specific_status.status_name if specific_status else "?")
		
		SUBJECT.TURN:
			condition_str = "Turn %s %s" % [NUMBER_COMP.keys()[compare], exact_number]
		
		SUBJECT.ROUND:
			condition_str = "Round %s %s" % [NUMBER_COMP.keys()[compare], exact_number]
			
		SUBJECT.EVERY_X_ROUND:
			condition_str = "Every %d Rounds" % exact_number
	
	return "%s%s: %s" % [not_prefix, subject_str, condition_str]
