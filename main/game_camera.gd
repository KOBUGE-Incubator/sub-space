
extends Camera2D

onready var level_container = get_node("../level_container")

func _ready():
	get_viewport().connect("size_changed", self, "update_size")
	update_size()

func update_size():
	var target = get_viewport_rect().size
	var current = level_container.get_level_size() # TODO?
	
	var min_target = min(target.width, target.height)
	var max_current = max(current.width, current.height)
	var zoom_ratio = max_current / min_target
	
	set_zoom(Vector2(zoom_ratio, zoom_ratio))

