extends Area2D
class_name Projectile

@export var speed: float = 144.0   # ~2.4 unidades/frame a 60fps

var direction: Vector2 = Vector2.RIGHT:
	set(value):
		direction = value
		rotation = value.angle()

func _ready() -> void:
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)
	$VisibleOnScreenEnabler2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_hit(_other: Node) -> void:
	queue_free()

func _on_screen_exited() -> void:
	queue_free()
