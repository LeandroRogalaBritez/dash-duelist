extends Node

@onready var sound_bank: SoundBank = $SoundBank

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Player.health_changed.connect($Hud._on_health_change)
	sound_bank.playMusic("background", -30.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
