extends Node
class_name StateMachine

@export var initial_state: State
@export var hurt_state: State
@export var die_state: State

var actual_state: State
var actor: Node
var previous_state: State

func _ready() -> void:
	actor = owner

	for child in get_children():
		if child is State:
			child.actor = actor
			child.state_machine = self

	if initial_state:
		call_deferred("_change_state", initial_state)

func _physics_process(_delta: float) -> void:
	if actual_state:
		actual_state.physics_process(_delta)

func change_state_to(new_state: State) -> void:
	_change_state(new_state)

func _change_state(new_state: State) -> void:
	if actual_state:
		actual_state.exit()
	previous_state = actual_state
	actual_state = new_state
	actual_state.enter()
	
func hurt() -> void:
	change_state_to(hurt_state)

func die() -> void:
	change_state_to(die_state)
