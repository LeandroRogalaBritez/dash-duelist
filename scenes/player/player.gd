extends CharacterBody2D
class_name Player

@export var normal_velocity: int = 192
@onready var sound_bank: SoundBank = $SoundBank

signal dash_cooldown_change(progress: float)

var last_direction := Vector2.DOWN
var dash_open := true
var iframes_active := false

func _ready() -> void:
	dash_cooldown_change.connect($CooldownDash.update)

func _process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
