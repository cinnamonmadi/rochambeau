extends KinematicBody2D

enum Direction { UP, RIGHT, DOWN, LEFT }
onready var input_timers = [$up_input_timer, $right_input_timer, $down_input_timer, $left_input_timer]
onready var sidestep_timer = $sidestep_timer
onready var sprite = $sprite

const SPEED: int = 100
const SIDESTEP_SPEED: int = 200
const GRAVITY: int = 5
const INPUT_TIMER_DELAY: float = 0.2

const JUMP_IMPULSE: int = 120
const JUMP_INPUT_DURATION: float = 0.06

export var player_number: int = 0
var input_names = ["", "", "", ""]
var input_attack: String
var input_block: String

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var crouched: bool = false
var shorthopping: bool = false
var sidestep_direction: int = 0
var blocking: bool = false

func _ready() -> void:
	var _unused = sidestep_timer.connect("timeout", self, "_on_sidestep_timeout")
	_unused = sprite.connect("animation_finished", self, "_on_animation_finished")
	set_player_number(player_number)

func set_player_number(number: int) -> void:
	player_number = number

	# Update input names
	var input_prefix: String = "p" + str(player_number) + "_"
	input_names = ["up", "right", "down", "left"]
	for input_direction in 4:
		input_names[input_direction] = input_prefix + input_names[input_direction]
	input_attack = input_prefix + "attack"
	input_block = input_prefix + "block"

func _physics_process(_delta: float) -> void:
	handle_directional_input()
	handle_action_input()
	move()
	update_sprite()

func handle_action_input() -> void:
	if Input.is_action_just_pressed(input_block):
		if not shorthopping and sidestep_direction == 0:
			blocking = true
	if Input.is_action_just_released(input_block):
		blocking = false

func handle_directional_input() -> void:
	for input_direction in 4:
		if Input.is_action_just_pressed(input_names[input_direction]):
			if input_timers[input_direction].is_stopped():
				input_timers[input_direction].start(INPUT_TIMER_DELAY)
				_on_direction_single_tap(input_direction)
			else:
				input_timers[input_direction].stop()
				_on_direction_double_tap(input_direction)
		if Input.is_action_just_released(input_names[input_direction]):
			_on_direction_release(input_direction)

func _on_direction_single_tap(input_direction: int) -> void:
	if input_direction == Direction.UP:
		if crouched:
			crouched = false
		direction.y = -1
	elif input_direction == Direction.DOWN:
		direction.y = 1
	elif input_direction == Direction.RIGHT:
		direction.x = 1
	elif input_direction == Direction.LEFT:
		direction.x = -1

func _on_direction_double_tap(input_direction: int) -> void:
	if input_direction == Direction.UP:
		shorthop()
	elif input_direction == Direction.DOWN:
		crouch()
	elif input_direction == Direction.RIGHT:
		sidestep(1)
	elif input_direction == Direction.LEFT:
		sidestep(-1)

func _on_direction_release(input_direction: int) -> void:
	if input_direction == Direction.UP:
		if Input.is_action_pressed(input_names[Direction.DOWN]):
			direction.y = 1
		else:
			direction.y = 0
	elif input_direction == Direction.DOWN:
		if Input.is_action_pressed(input_names[Direction.UP]):
			direction.y = -1
		else:
			direction.y = 0
	elif input_direction == Direction.RIGHT:
		if Input.is_action_pressed(input_names[Direction.LEFT]):
			direction.x = -1
		else:
			direction.x = 0
	elif input_direction == Direction.LEFT:
		if Input.is_action_pressed(input_names[Direction.RIGHT]):
			direction.x = 1
		else:
			direction.x = 0

func move() -> void:
	if sidestep_direction == 0:
		velocity.x = direction.x * SPEED
	elif not blocking:
		velocity.x = sidestep_direction * SIDESTEP_SPEED
	velocity.y += GRAVITY

	var grounded = is_on_floor()
	if grounded and velocity.y >= 5:
		velocity.y = 5

	var _linear_velocity: Vector2 = move_and_slide(velocity, Vector2(0, -1))

func update_sprite() -> void:
	if shorthopping:
		sprite.play("shorthop")
	elif crouched:
		if blocking and direction.y == 0:
			sprite.play("crouch_block_mid")
		elif blocking and direction.y == 1:
			sprite.play("crouch_block_low")
		elif not blocking:
			sprite.play("crouch_idle")
	else:
		if blocking and direction.y == -1:
			sprite.play("block_high")
		elif blocking and direction.y == 0:
			sprite.play("block_mid")
		elif blocking and direction.y == 1:
			sprite.play("block_low")
		elif not blocking:
			sprite.play("idle")

func shorthop() -> void:
	if blocking or sidestep_direction != 0:
		return
	shorthopping = true

func crouch() -> void:
	if shorthopping or sidestep_direction != 0:
		return
	crouched = true

func sidestep(step_direction: int) -> void:
	if blocking or sidestep_direction != 0:
		return
	sidestep_direction = step_direction
	sidestep_timer.start(0.2)

func _on_sidestep_timeout() -> void:
	sidestep_direction = 0

func _on_animation_finished():
	if sprite.animation == "shorthop":
		shorthopping = false
