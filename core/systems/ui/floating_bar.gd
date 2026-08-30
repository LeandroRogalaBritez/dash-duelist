extends ProgressBar
class_name FloatingBar

var target: Node2D
var offset: Vector2

func _ready() -> void:
	target = get_parent()
	offset = position 
	top_level = true 

func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position + offset

func update(_progress: float) -> void:
	value = _progress * 100.0
