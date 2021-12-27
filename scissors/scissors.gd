extends KinematicBody2D

enum Direction { UP, RIGHT, DOWN, LEFT }
enum AttackDirection { NONE = -2, HIGH = -1, MID = 0, LOW = 1 }

onready var input_timers = [$up_input_timer, $right_input_timer, $down_input_timer, $left_input_timer]
onready var sidestep_timer = $sidestep_timer
onready var blockstun_timer = $blockstun_timer
onready var parry_timer = $parry_timer
onready var sprite = $sprite
onready var hurtbox = $hurtbox

const SPEED: int = 100
const CROUCH_SPEED: int = 20
const SIDESTEP_SPEED: int = 200
const GRAVITY: int = 5
const INPUT_TIMER_DELAY: float = 0.2
const PARRY_WINDOW: float = 0.2
const BLOCKSTUN_DURATION: float = 0.5

export var player_number: int = 0
var opponent_name: String
var input_names = ["", "", "", ""]
var input_attack: String
var input_block: String

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var crouched: bool = false
var shorthopping: bool = false
var sidestep_direction: int = 0
var blocking: bool = false
var attack_direction: int = AttackDirection.NONE
var attack_lethal: bool = false

func _ready() -> void:
	var _unused = sidestep_timer.connect("timeout", self, "_on_sidestep_timeout")
	_unused = sprite.connect("animation_finished", self, "_on_animation_finished")
	_unused = sprite.connect("frame_changed", self, "_on_animation_frame_changed")
	set_player_number(player_number)

func set_player_number(number: int) -> void:
	player_number = number
	set_name("player_" + str(player_number))
	if player_number == 1:
		opponent_name = "player_2"
	else:
		opponent_name = "player_1"

	# Update input names
	var input_prefix: String = "p" + str(player_number) + "_"
	input_names = ["up", "right", "down", "left"]
	for input_direction in 4:
		input_names[input_direction] = input_prefix + input_names[input_direction]
	input_attack = input_prefix + "attack"
	input_block = input_prefix + "block"

	if player_number == 2:
		sprite.flip_h = true
		hurtbox.position.x *= -1

func _physics_process(_delta: float) -> void:
	handle_directional_input()
	handle_action_input()
	move()
	check_attack_hit()
	update_sprite()

func handle_action_input() -> void:
	if Input.is_action_just_pressed(input_attack):
		if attack_direction == AttackDirection.NONE and not shorthopping and sidestep_direction == 0 and blockstun_timer.is_stopped():
			attack_direction = int(direction.y)
	var was_blocking = blocking
	blocking = (not blockstun_timer.is_stopped()) or (Input.is_action_pressed(input_block) and not shorthopping and sidestep_direction == 0 and attack_direction == AttackDirection.NONE)
	if blocking and not was_blocking:
		parry_timer.start(PARRY_WINDOW)
	elif not blocking:
		parry_timer.stop()

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
		if player_number == 2 and attack_direction != AttackDirection.NONE and sprite.frame == 0:
			attack_direction = AttackDirection.NONE
	elif input_direction == Direction.LEFT:
		direction.x = -1
		if player_number == 1 and attack_direction != AttackDirection.NONE and sprite.frame == 0:
			attack_direction = AttackDirection.NONE

func _on_direction_double_tap(input_direction: int) -> void:
	if not blockstun_timer.is_stopped():
		return
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
	if blocking or attack_direction != AttackDirection.NONE:
		velocity.x = 0
	elif crouched:
		velocity.x = direction.x * CROUCH_SPEED
	elif sidestep_direction == 0:
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
	else:
		var anim_name = ""
		if crouched:
			anim_name += "crouch_"
		if blocking:
			anim_name += "block_"
			if direction.y == -1:
				anim_name += "high"
			elif direction.y == 0:
				anim_name += "mid"
			elif direction.y == 1:
				anim_name += "low"
		elif attack_direction != AttackDirection.NONE:
			anim_name += "attack_"
			if attack_direction == AttackDirection.HIGH:
				anim_name += "high"
			elif attack_direction == AttackDirection.MID:
				anim_name += "mid"
			elif attack_direction == AttackDirection.LOW:
				anim_name += "low"
		else:
			anim_name += "idle"
		sprite.play(anim_name)

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
	crouched = false
	sidestep_direction = step_direction
	sidestep_timer.start(0.2)

func _on_sidestep_timeout() -> void:
	sidestep_direction = 0

func _on_animation_finished() -> void:
	if sprite.animation == "shorthop":
		shorthopping = false
	if sprite.animation.begins_with("attack_") or sprite.animation.begins_with("crouch_attack_"):
		attack_direction = AttackDirection.NONE

func _on_animation_frame_changed() -> void:
	if attack_direction != AttackDirection.NONE and sprite.frame == 1:
		attack_lethal = true

func check_attack_hit() -> void:
	if attack_direction == AttackDirection.NONE or sprite.frame != 1 or not attack_lethal:
		return
	for body in hurtbox.get_overlapping_bodies():
		if body.name == opponent_name:
			var attack_success = body.is_hit(attack_direction)
			if attack_success:
				body.handle_hit()
			attack_lethal = false

func is_hit(incoming_attack_direction: int) -> bool:
	if blocking and direction.y == incoming_attack_direction:
		if parry_timer.is_stopped():
			blockstun_timer.start(BLOCKSTUN_DURATION)
			print("blockstun!")
		else:
			print("parry!")
		return false
	elif crouched and incoming_attack_direction == AttackDirection.HIGH:
		return false
	elif shorthopping and incoming_attack_direction == AttackDirection.LOW:
		return false
	elif attack_direction == incoming_attack_direction and sprite.frame == 1:
		return false
	return true

func handle_hit() -> void:
	pass
