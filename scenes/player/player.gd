extends CharacterBody2D
class_name Player

@export var normal_velocity: int = 192
@onready var sound_bank: SoundBank = $SoundBank
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var state_machine: StateMachine = $StateMachine

signal dash_cooldown_change(progress: float)
signal health_changed(current_hp: int)
signal died

var is_dead: bool = false
var last_direction := Vector2.DOWN
var dash_open := true
var hp: int = 100
var dash_iframes_active: bool = false
var damage_iframes_active: bool = false

func _ready() -> void:
	dash_cooldown_change.connect($CooldownDash.update)
	
func is_invulnerable() -> bool:
	return dash_iframes_active or damage_iframes_active
	
func take_damage(amount: int) -> void:
	if is_invulnerable():
		return
		
	hp -= amount
	health_changed.emit(hp)
		
	if hp <= 0:
		die()
		return
	
	state_machine.hurt()

func move_with_input() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * normal_velocity
	move_and_slide()

	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()

	if input_dir.x != 0:
		sprite.flip_h = input_dir.x < 0

func die() -> void:
	if is_dead:
		return
	is_dead = true
	hurtbox.monitoring = false
	state_machine.die()
