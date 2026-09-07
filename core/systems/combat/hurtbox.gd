extends Area2D
class_name Hurtbox

@onready var actor: Node = get_parent()

func _ready() -> void:
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _on_hit(_other: Node) -> void:
	if (actor.has_method("is_invulnerable")) and actor.is_invulnerable():
		return
	if (actor.has_method("take_damage")):
		actor.take_damage(20)
