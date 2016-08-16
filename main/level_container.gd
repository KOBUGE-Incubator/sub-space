
extends Node2D

const TILE_WALL = 0
const TILE_WALK = 1
const TILE_ZOOM = 2
const TILE_OUTZOOM = 3
const TILES = [
	TILE_WALK,
	TILE_ZOOM,
	TILE_WALL
]

export var tile_size = 128
export var level_size = Vector2(5, 5)
export var level_offset = Vector2(2, 2)
export var transition_time = 0.7
export var opacity_transition_time = 0.9

var level_reached = [0]
var level

onready var tween = get_node("tween")
onready var timer = get_node("timer")

func _ready():
	level = instance_level(level_reached)
	add_child(level)

func can_move_to_pos(pos, _level = level):
	var tile = get_tile_at_pos(pos, _level)
	return tile != TILE_WALL

func apply_action_of_pos(pos, movement, player):
	var tile = get_tile_at_pos(pos)
	if tile == TILE_OUTZOOM:
		var last_id = level_reached[-1]
		level_reached.pop_back()
		var new_level = instance_level(level_reached)
		if !new_level:
			level_reached.push_back(last_id)
			return false
		
		var target_pos = get_zoom_in_tile_pos_with_id(last_id, new_level) + movement
		var tile = get_tile_at_pos(target_pos, new_level)
		if tile == TILE_WALL or tile == TILE_OUTZOOM: # Recursive outzoom is not yet supported...
			level_reached.push_back(last_id)
			return false
		
		player.freeze()
		zoom(false, player, target_pos, new_level)
		return target_pos
	elif tile == TILE_ZOOM:
		level_reached.push_back(get_zoom_in_tile_id_at(pos, level))
		var new_level = instance_level(level_reached)
		if !new_level:
			level_reached.pop_back()
			return false
		
		var target_pos = level_offset * -movement
		
		var tile = get_tile_at_pos(target_pos, new_level)
		if tile == TILE_WALL or tile == TILE_ZOOM: # Recursive zoomin is not yet supported...
			level_reached.pop_back()
			return false
		
		player.freeze()
		zoom(true, player, target_pos, new_level)
		return target_pos

func zoom(zoom_in, player, target_pos, new_level):
	add_child(new_level)
	level.set_z(-1)
	
	var transition = Tween.TRANS_BOUNCE #Tween.TRANS_ELASTIC
	var easing = Tween.EASE_OUT
	var opacity_transition = Tween.TRANS_LINEAR
	var opacity_easing = Tween.EASE_OUT
	
	var new_level_scale = new_level.get_scale()
	var new_level_pos = new_level.get_pos()
	var new_level_rot = new_level.get_rot()
	var current_level_scale = level.get_scale()
	var current_level_pos = level.get_pos()
	var current_level_rot = level.get_rot()
	
	if zoom_in:
		tween.interpolate_property(level, "transform/scale", current_level_scale, current_level_scale * level_size, transition_time, transition, easing)
		tween.interpolate_property(level, "transform/pos", current_level_pos, current_level_pos * level_size, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/scale", new_level_scale / level_size, new_level_scale, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/pos", new_level_pos / level_size, new_level_pos, transition_time, transition, easing)
	else:
		tween.interpolate_property(level, "transform/scale", current_level_scale, current_level_scale / level_size, transition_time, transition, easing)
		tween.interpolate_property(level, "transform/pos", current_level_pos, current_level_pos / level_size, transition_time, transition, easing)
		
		tween.interpolate_property(new_level, "transform/scale", new_level_scale * level_size, new_level_scale, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/pos", new_level_pos * level_size, new_level_pos, transition_time, transition, easing)
	
	tween.interpolate_property(level, "transform/rot", current_level_rot, current_level_rot, transition_time, transition, easing)
	tween.interpolate_property(new_level, "transform/rot", new_level_rot, new_level_rot, transition_time, transition, easing)
	tween.interpolate_property(level, "visibility/opacity", 1, 0, opacity_transition_time, opacity_transition, opacity_easing)
	tween.interpolate_property(new_level, "visibility/opacity", 0, 1, opacity_transition_time, opacity_transition, opacity_easing)
	
	tween.interpolate_property(player, "transform/pos", player.get_pos(), target_pos * tile_size, transition_time, transition, easing)
	tween.start()
	
	var old_level = level
	level = new_level
	
	timer.set_wait_time(min(opacity_transition_time, transition_time))
	timer.start()
	yield(timer, "timeout")
	
	player.unfreeze(true)
	
	if abs(opacity_transition_time - transition_time) > 0:
		timer.set_wait_time(abs(opacity_transition_time - transition_time))
		timer.start()
		yield(timer, "timeout")
	
	old_level.queue_free()

func instance_level(level_array):
	var name = ""
	for part in level_array:
		name += str("_", part)
	var scene = load("res://levels/level%s.tscn" % name)
	if scene:
		var node = scene.instance()
		return node
	else:
		print("Can't find levels/level", name, ".tscn")
		return null

func get_tile_at_pos(pos, _level = level):
	var tile = _level.get_cellv(pos + level_offset)
	if tile >= 0:
		return TILES[tile]
	else:
		return TILE_OUTZOOM

func get_zoom_in_tile_pos_with_id(id, _level = level):
	var found = 0
	for x in range(-level_offset.x, level_offset.x+1):
		for y in range(-level_offset.y, level_offset.y+1):
			if get_tile_at_pos(Vector2(x, y), _level) == TILE_ZOOM:
				if found == id:
					return Vector2(x,y)
				found += 1
	return Vector2()

func get_zoom_in_tile_id_at(pos, _level = level):
	var found = 0
	for x in range(-level_offset.x, pos.x+1):
		for y in range(-level_offset.y, level_offset.y+1):
			if get_tile_at_pos(Vector2(x, y), _level) == TILE_ZOOM:
				if Vector2(x, y).distance_squared_to(pos) < 0.0001:
					return found
				found += 1

func get_level_size():
	return Vector2(5,5) * tile_size
	
