class_name CardDefinition
extends Resource

@export var id: String
@export var display_name: String
@export_enum("Flame", "Tide", "Gale", "Support") var element: String
@export_enum("Common", "Uncommon", "Rare", "Legendary") var rarity: String
@export var max_hp: int = 0
@export var retreat_cost: int = 1
@export var attacks: Array[Resource] = []
@export var effect: EffectDefinition
@export_multiline var rules_text: String
@export_multiline var lore: String
@export_file("*.png") var art_path: String


func is_creature() -> bool:
	return element != "Support"
