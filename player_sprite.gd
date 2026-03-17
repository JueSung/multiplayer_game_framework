extends Sprite2D

var target_state = {
	"position" : Vector2(0,0),
	"rotation" : 0
}

var prev_state = {
	"position" : Vector2(0,0),
	"rotation" : 0
}

var tick_length = 1.0 / Engine.physics_ticks_per_second
var accumulator = 0.0

func _ready():
	set_as_top_level(true) # because gonna be interpolated



func _process(delta):
	prev_state = target_state.duplicate()
	target_state = get_parent().get_state()
	accumulator += delta
	var alpha = accumulator/tick_length
	global_position = prev_state["position"] + (target_state["position"] - prev_state["position"]) * alpha
	
	#var alpha = min(1., delta / (tick_length * 1.5))
	# lerp to
	#print(alpha)
	#global_position = global_position.lerp(target_state["position"], alpha)
	
	while accumulator > tick_length:
		accumulator -= tick_length
