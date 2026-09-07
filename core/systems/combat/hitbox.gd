extends Area2D
class_name Hitbox

@onready var actor: Player = get_parent()

func _ready() -> void:
	monitoring = false   # começa desligada
	area_entered.connect(_on_hit_enemy)
	body_entered.connect(_on_hit_enemy)

func _on_hit_enemy(other: Node) -> void:
	if other.has_method("die"):
		other.die()
