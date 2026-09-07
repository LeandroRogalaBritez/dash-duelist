extends CanvasLayer

@onready var health: ProgressBar = $Heath

func _on_health_change(_health: float) -> void:
	health.value = _health
