
extends Node2D

const TILE_WALL = 0
const TILE_WALK = 1
const TILE_ZOOM = 2
const TILE_OUTZOOM = 3
const TILE_SAME_DIR = 4
const TILES = [
	TILE_WALK,
	TILE_ZOOM,
	TILE_WALL,
	TILE_SAME_DIR
]

const ANIM_ZOOM_IN = 1
const ANIM_ZOOM_OUT = 2
const ANIM_SLIDE = 3

export var tile_size = 128
export var level_size = Vector2(5, 5)
export var level_offset = Vector2(2, 2)
export var transition_time = 0.7
export var opacity_transition_time = 0.9

var level_reached_path = "/0"
var level
var last_movement = Vector2()

onready var tween = get_node("tween")

func _ready():
	level = instance_level(level_reached_path)
	add_child(level)

func can_move_to_pos(pos, _level = level):
	var tile = get_tile_at_pos(pos, _level)
	return tile != TILE_WALL

func apply_action_of_pos(pos, movement, player, _level = level, _trans_path = ".", _trans_positions = null):
	if _trans_positions == null: _trans_positions = [pos - movement]
	
	var pretile = get_tile_at_pos(pos - movement, _level)
	var tile = get_tile_at_pos(pos, _level)
	if tile == TILE_WALL:
		return false
	
	var c_last_movement = last_movement
	if tile == TILE_SAME_DIR:
		last_movement = movement
	
	if pretile == TILE_SAME_DIR:
		if abs(c_last_movement.dot(movement)) < 0.75:
			last_movement = c_last_movement
			return false
	
	if tile == TILE_OUTZOOM:
		var current_path = simplify_path(level_reached_path.plus_file(_trans_path))
		_trans_path = _trans_path.plus_file("..")
		var new_level_path = simplify_path(level_reached_path.plus_file(_trans_path))
		var new_level = instance_level(new_level_path)
		if new_level:
			var target_pos = get_zoom_in_tile_pos_with_id(int(current_path.get_file()), new_level) + movement
			
			_trans_positions.push_back(target_pos)
			
			return apply_action_of_pos(target_pos, movement, player, new_level, _trans_path, _trans_positions)
		else:
			_trans_path = _trans_path.get_base_dir()
	
	if tile == TILE_ZOOM:
		_trans_path = _trans_path.plus_file(str(get_zoom_in_tile_id_at(pos, _level)))
		var new_level_path = simplify_path(level_reached_path.plus_file(_trans_path))
		var new_level = instance_level(new_level_path)
		if new_level:
			var target_pos = level_offset * -movement
			
			var path = _trans_path.split("/")
			var n = 0
			var i = 0
			var peak = 0
			while i < path.size() and (path[i] == "." or path[i] == ""): i += 1
			while i < path.size() and path[i] == "..":
				i += 1
				n += 1
			peak = n
			while i < path.size() and path[i] != ".." and n > 0:
				i += 1
				n -= 1
			
			if n == 0 and peak > 0:
				target_pos = _trans_positions[peak-1] - level_offset * 2 * movement
			
			_trans_positions.push_back(target_pos)
			
			return apply_action_of_pos(target_pos, movement, player, new_level, _trans_path, _trans_positions)
		else:
			_trans_path = _trans_path.get_base_dir()
	
	if _trans_path != ".":
		#anim
		transition(_trans_path, player, movement, _trans_positions, level_reached_path)
		level_reached_path = simplify_path(level_reached_path.plus_file(_trans_path))
		return pos
	return null

func transition(path, player, movement, target_positions = [], current_path = level_reached_path):
	path = Array(path.split("/"))
	
	while !path.empty() and (path[0] == "." or path[0] == ""):
		path.pop_front()
		target_positions.pop_front()
	if path.empty(): return
	
	var animation_type = ANIM_ZOOM_IN
	if path[0] == "..":
		var n = 0
		var i = 0
		while i < path.size() and path[i] == "..":
			i += 1
			n += 1
		while i < path.size() and path[i] != ".." and n > 0:
			i += 1
			n -= 1
		
		if n == 0:
			for x in range(i - 1):
				current_path = simplify_path(current_path.plus_file(path[0]))
				path.pop_front()
				target_positions.pop_front()
			animation_type = ANIM_SLIDE
		else:
			animation_type = ANIM_ZOOM_OUT
	
	player.freeze()
	var new_level_path = simplify_path(current_path.plus_file(path[0]))
	var new_level = instance_level(new_level_path)
	var target_pos = target_positions[0]
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
	
	if animation_type == ANIM_ZOOM_IN:
		var zoom_world_pos = get_zoom_in_tile_pos_with_id(int(new_level_path.get_file()), level) * tile_size
		tween.interpolate_property(level, "transform/pos", current_level_pos, (current_level_pos - zoom_world_pos) * level_size, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/pos", new_level_pos / level_size + zoom_world_pos, new_level_pos, transition_time, transition, easing)
		
		tween.interpolate_property(level, "transform/scale", current_level_scale, current_level_scale * level_size, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/scale", new_level_scale / level_size, new_level_scale, transition_time, transition, easing)
	elif animation_type == ANIM_ZOOM_OUT:
		var zoom_world_pos = get_zoom_in_tile_pos_with_id(int(current_path.get_file()), new_level) * tile_size
		tween.interpolate_property(level, "transform/pos", current_level_pos, current_level_pos / level_size + zoom_world_pos, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/pos", (new_level_pos - zoom_world_pos) * level_size, new_level_pos, transition_time, transition, easing)
		
		tween.interpolate_property(level, "transform/scale", current_level_scale, current_level_scale / level_size, transition_time, transition, easing)	
		tween.interpolate_property(new_level, "transform/scale", new_level_scale * level_size, new_level_scale, transition_time, transition, easing)
	elif animation_type == ANIM_SLIDE:
		tween.interpolate_property(level, "transform/pos", current_level_pos, current_level_pos - movement * level_size * tile_size, transition_time, transition, easing)
		tween.interpolate_property(new_level, "transform/pos", new_level_pos + movement * level_size * tile_size, new_level_pos, transition_time, transition, easing)
	
	tween.interpolate_property(level, "transform/rot", current_level_rot, current_level_rot, transition_time, transition, easing)
	tween.interpolate_property(new_level, "transform/rot", new_level_rot, new_level_rot, transition_time, transition, easing)
	
	tween.interpolate_property(level, "visibility/opacity", 1, 0, opacity_transition_time, opacity_transition, opacity_easing)
	tween.interpolate_property(new_level, "visibility/opacity", 0, 1, opacity_transition_time, opacity_transition, opacity_easing)
	
	tween.interpolate_property(player, "transform/pos", player.get_pos(), target_pos * tile_size, transition_time, transition, easing)
	tween.start()
	
	var old_level = level
	level = new_level
	
	var timer = Timer.new()
	timer.set_wait_time(min(opacity_transition_time, transition_time))
	timer.start()
	add_child(timer)
	yield(timer, "timeout")
	
	path.pop_front()
	target_positions.pop_front()
	transition(join_path(path, ""), player, movement, target_positions, new_level_path)
	
	player.unfreeze(true)
	
	if abs(opacity_transition_time - transition_time) > 0:
		timer.set_wait_time(abs(opacity_transition_time - transition_time))
		timer.start()
		yield(timer, "timeout")
	
	old_level.queue_free()

func instance_level(level_path):
	var name = level_path.replace("/", "_")
	if level_path == "/": name = ""
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

static func simplify_path(path):
	var dirs = []
	var p = ""
	if path.is_abs_path(): p = "/"
	
	for s in path.split("/"):
		if s == ".": continue
		elif s == "..": dirs.pop_back()
		elif s != "": dirs.push_back(s)
	
	return join_path(dirs, p)

static func join_path(dirs, base = "/", maxi = -1):
	var i = 0
	for d in dirs:
		if maxi > 0 and i < maxi:
			break
		base += str(d, "/")
		i += 1
	
	return base.left(max(base.length() - 1,1))
