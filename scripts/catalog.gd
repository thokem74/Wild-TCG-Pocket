extends Node

const ELEMENTS: Array[String] = ["Flame", "Tide", "Gale"]
const COLORS: Dictionary = {
	"Flame": Color("e86b50"),
	"Tide": Color("398bce"),
	"Gale": Color("399c82"),
	"Support": Color("9674c7")
}
var cards: Dictionary = {}
var ordered_ids: Array[String] = []
var recipes: Array[DeckRecipe] = []


func _ready() -> void:
	var ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for id: String in ids:
		cards[id] = load("res://data/cards/%s.tres" % id)
		ordered_ids.append(id)
	for element: String in ELEMENTS:
		recipes.append(load("res://data/decks/%s.tres" % element.to_lower()))


func card(id: String) -> CardDefinition:
	return cards.get(id)


func validate_deck(ids: Array, owned: Dictionary = {}) -> String:
	if ids.size() != 20:
		return "A deck needs exactly 20 cards (%d/20)." % ids.size()
	var counts: Dictionary = {}
	var creatures: int = 0
	for id: String in ids:
		if not cards.has(id):
			return "Unknown card: " + id
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > 2:
			return "Only two copies of %s are allowed." % card(id).display_name
		if not owned.is_empty() and counts[id] > int(owned.get(id, 0)):
			return "You do not own enough copies of " + card(id).display_name
		if card(id).is_creature():
			creatures += 1
	return "" if creatures > 0 else "Include at least one creature."
