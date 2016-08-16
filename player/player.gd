
extends Node2D

const movement_actions = {
	"right": Vector2(1, 0),
	"left": Vector2(-1, 0),
	"down": Vector2(0, 1),
	"up": Vector2(0, -1)
}

export(float) var movement_time = 0.5

onready var level_container = get_parent()
onready var animation_player = get_node("animation_player")

var current_action = null
var queued_actions = []

var movement_time_passed = 0
var current_pos = Vector2()
var movement = Vector2()

var frozen = 0

func _ready():
	current_pos = (get_pos() / level_container.tile_size).snapped(Vector2(1,1))
	set_process_input(true)

func _input(event):
	if event.is_pressed() and !event.is_echo():
		for action in movement_actions:
			if event.is_action(action):
				queued_actions.push_back(action)
		if event.is_action("ui_cancel"):
			queued_actions = []
		if current_action == null:
			do_next_action()
		

func _process(delta):
	movement_time_passed += delta
	
	if movement_time_passed > movement_time: # Done
		set_pos(current_pos * level_container.tile_size)
		current_action = null
		movement = Vector2()
		set_process(false)
		do_next_action()
	else: # Interpolate
		var t = movement_time_passed / movement_time
		var momentary_pos = (current_pos - movement).linear_interpolate(current_pos, t)
		set_pos(momentary_pos * level_container.tile_size)

func do_next_action():
	if frozen:
		return
	while !queued_actions.empty() and current_action == null:
		current_action = queued_actions[0]
		queued_actions.pop_front()
		
		if movement_actions.has(current_action):
			movement = movement_actions[current_action]
			if !level_container.can_move_to_pos(current_pos + movement):
				play_cant_move()
				current_action = null
				continue
			else:
				var new_pos = level_container.apply_action_of_pos(current_pos + movement, movement, self)
				if new_pos != null: # We are assigned a new position, assume the container would be so kind as to move us
					if typeof(new_pos) == TYPE_VECTOR2:
						current_pos = new_pos
						queued_actions = []
						current_action = null
						return
					elif typeof(new_pos) == TYPE_BOOL:
						if !new_pos: # Turns out we actually can't move there
							play_cant_move()
							current_action = null
							continue
				current_pos += movement
				movement_time_passed = 0
				set_process(true)
		else:
			current_action = null # Loop again -- invalid action

func play_cant_move():
	set_rot(movement.angle())
	animation_player.play("slap")
	yield(animation_player, "finished")
	set_rot(0)

func freeze():
	frozen += 1

func unfreeze(clear = false):
	if frozen > 0:
		frozen -= 1
		if clear:
			queued_actions = []
		else:
			do_next_action()
