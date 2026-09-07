extends CharacterBody2D
class_name Enemy

@export var normal_velocity: int = 96
@export var detection_range: float = 220.0
@export var attack_range: float = 120.0
@export var attack_cooldown_frames: int = 110
@export var projectile_scene: PackedScene

signal health_changed(current_hp: int)
signal died

var player: Player
var hp: int = 100
var is_dying: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_bank: SoundBank = $SoundBank
@onready var state_machine: StateMachine = $StateMachine
@onready var hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	health_changed.connect($Health.update)
	player = $"../Player"

func distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

func move_toward_player() -> void:
	if player == null:
		return
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * normal_velocity
	move_and_slide()

	if direction.x != 0:
		sprite.flip_h = direction.x < 0

func shoot() -> void:
	var projectile := projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.direction = (player.global_position - global_position).normalized()
	sound_bank.playSfx("shoot")
	
func take_damage(amount: int) -> void:
	if is_dying:
		return

	hp -= amount
	health_changed.emit(hp)

	if hp <= 0:
		is_dying = true
		state_machine.die()
	else:
		state_machine.hurt()
