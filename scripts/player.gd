class_name Player
extends CharacterBody2D

var cursor = preload("res://art/cursor/square.png")

var screen_size
var direction = Macros.Direction.RIGHT

var currPowerUp = null

var isStuck: bool = false
var onGear: bool = false
var hud_node
var isUsingButton: bool = false
var needHintCount: int = 0

var animations = {
	null: {
		"walk": "walk",
		"fall": "fall",
		"idle": "idle"
	},
	Macros.PowerUp.ELETRICAL: {
		"walk": "eletric_walk",
		"fall": "eletric_fall",
		"idle": "eletric_idle"
	},
	Macros.PowerUp.MECHANICAL: {
		"walk": "mechanical_walk",
		"fall": "mechanical_fall",
		"idle": "mechanical_idle"
	},
}

@export var speed = 0
@export var gravity = 5

func _ready():
	screen_size = get_viewport_rect().size
	hud_node = get_parent().get_parent().get_node("HUD")
	
	Signals.connect("eletric_door_spotted_engineer", _on_trying_to_fix_door)
	Signals.connect("eletric_door_is_fixed", _on_stopping_fixing_door)
	Signals.connect("platform_spotted_engineer", _on_trying_to_activate_gear)
	Signals.connect("gear_spotted_engineer", _on_trying_to_enter_gear)
	Signals.connect("gear_exiting_engineer", _on_trying_to_exit_gear)


func _on_trying_to_fix_door(name, door_name):
	if name != self.name:
		return
	if currPowerUp != Macros.PowerUp.ELETRICAL:
		return
		
	isUsingButton = true
	set_physics_process(false)
	$AnimatedSprite2D.play("eletric_fix")
	Signals.emit_signal("eletric_door_is_being_fixed", door_name)
	
	$ProgressBar.visible = true
	$Timer.start(3.0)

func _on_stopping_fixing_door(name):
	if name != self.name:
		return
		
	$ProgressBar.visible = false
	$Timer.stop()
	currPowerUp = null
	set_physics_process(true)
	isUsingButton = false
	
func _process(delta):
	if isUsingButton:
		$ProgressBar.value = (3 - $Timer.get_time_left())
		
func _physics_process(delta):
	velocity.y += gravity
	velocity.x = direction * speed

	move_and_slide()
	
	var falling_animation
	var walking_animation
	var idle_animation
	
	if currPowerUp in [Macros.PowerUp.ELETRICAL, Macros.PowerUp.MECHANICAL]:
		falling_animation = animations[currPowerUp]["fall"]
		walking_animation = animations[currPowerUp]["walk"]
		idle_animation = animations[currPowerUp]["idle"]
	else:
		falling_animation = animations[null]["fall"]
		walking_animation = animations[null]["walk"]
		idle_animation = animations[null]["idle"]
	
	if velocity.y > gravity:
		$AnimatedSprite2D.play(falling_animation)
	elif onGear:
		$AnimatedSprite2D.play(idle_animation)
	else:
		$AnimatedSprite2D.play(walking_animation)
		
	if is_on_wall() and !onGear:
		direction = -direction
		$AnimatedSprite2D.flip_h = !$AnimatedSprite2D.flip_h
	
	_check_is_dead()

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton&&event.pressed:
		if currPowerUp != null:
			return
		if isStuck or hud_node.currPowerUp == null:
			return

		$PowerupSound.play()
		currPowerUp = hud_node.currPowerUp
		hud_node._decrease_powerup_count()
		
		match currPowerUp:
			Macros.PowerUp.PHYSICAL_SHRINK:
				$Timer.stop()
				$Timer.start(3.0)
				$AnimationPlayer.play("shrink")
			Macros.PowerUp.PHYSICAL_EXPAND:
				$Timer.stop()
				$Timer.start(3.0)
				$AnimationPlayer.play("expand")

func _on_trying_to_activate_gear(name):
	if name != self.name:
		return
	
	# does not have powerup, but it's still on top of platform
	if currPowerUp != Macros.PowerUp.MECHANICAL:
		needHintCount += 1
		
		if (needHintCount >= 8):
			$Thinking.visible = true
		
		return
	
	# stops on top of the platform, does not move anymore (sacrifice)
	set_physics_process(false)
	$AnimatedSprite2D.play("mechanical_idle")
	if $Thinking.is_visible():
		$Thinking.visible = false
	
	Signals.emit_signal("platform_body_is_mechanical", "null")

func _on_mouse_entered():
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(24, 24))

func _on_mouse_exited():
	Input.set_custom_mouse_cursor(null)

func _on_power_ups_timer_timeout():
	if isStuck and currPowerUp == Macros.PowerUp.PHYSICAL_SHRINK:
		$Timer.start(0.1)
		return
	currPowerUp = null
	$AnimationPlayer.play_backwards()

func _on_area_2d_body_entered(body):
	isStuck = true
	if currPowerUp == Macros.PowerUp.PHYSICAL_EXPAND and $AnimationPlayer.is_playing:
		$AnimationPlayer.pause()
	
func _on_area_2d_body_exited(body):
	isStuck = false
	if $AnimationPlayer.assigned_animation == "expand":
		$AnimationPlayer.play()
	
func _on_trying_to_enter_gear(name):
	if name == self.name:
		onGear = true

func _on_trying_to_exit_gear(name):
	if name == self.name:
		onGear = false

func _check_is_dead():
	if (position.y > get_viewport().size.y):
		queue_free()
		hud_node._decrease_player_count()	
