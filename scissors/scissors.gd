extends KinematicBody2D

onready var jump_input_timer: Timer = $jump_input_timer

const SPEED: int = 150
const GRAVITY: int = 5
const JUMP_IMPULSE: int = 120
const JUMP_INPUT_DURATION: float = 0.06

export var player_number: int = 0
var input_left: String
var input_right: String
var input_jump: String

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_player_number(player_number)

func set_player_number(number: int) -> void:
	player_number = number

	# Update input names
	var input_prefix: String = "p" + str(player_number) + "_"
	input_left = input_prefix + "left"
	input_right = input_prefix + "right"
	input_jump = input_prefix + "jump"

func _physics_process(_delta: float) -> void:
	handle_input()
	move()

func handle_input() -> void:
	if Input.is_action_just_pressed(input_left):
		direction.x = -1
	if Input.is_action_just_pressed(input_right):
		direction.x = 1
	if Input.is_action_just_released(input_left):
		if Input.is_action_pressed(input_right):
			direction.x = 1
		else:
			direction.x = 0
	elif Input.is_action_just_released(input_right):
		if Input.is_action_pressed(input_left):
			direction.x = -1
		else:
			direction.x = 0
	if Input.is_action_just_pressed(input_jump):
		jump_input_timer.start(JUMP_INPUT_DURATION)

func move() -> void:
	velocity.x = direction.x * SPEED
	velocity.y += GRAVITY

	var grounded = is_on_floor()
	if grounded and not jump_input_timer.is_stopped():
		jump()
	if grounded and velocity.y >= 5:
		velocity.y = 5

	var _linear_velocity: Vector2 = move_and_slide(velocity, Vector2(0, -1))

func jump() -> void:
	velocity.y = -JUMP_IMPULSE
