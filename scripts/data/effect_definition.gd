class_name EffectDefinition
extends Resource

## Explicit effect kinds are shared by support cards and creature attacks.
@export_enum("DAMAGE", "HEAL", "DRAW", "MOVE_ENERGY", "BOOST") var kind: String = "DAMAGE"
@export var amount: int = 0
