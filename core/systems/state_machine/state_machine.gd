extends Node
class_name StateMachine

@export var initial_state: State

var actual_state: State
var actor: Node

func _ready() -> void:
	actor = owner

	for child in get_children():
		if child is State:
			child.actor = actor
			child.state_machine = self

	if initial_state:
		_change_state(initial_state)

func _physics_process(_delta: float) -> void:
	if actual_state:
		actual_state.physics_process(_delta)

func change_state_to(new_state: State) -> void:
	_change_state(new_state)

func _change_state(new_state: State) -> void:
	if actual_state:
		actual_state.exit()
	actual_state = new_state
	actual_state.enter()
