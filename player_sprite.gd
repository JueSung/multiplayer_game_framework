extends Sprite2D

const smoothing_factor = 0.15 * 60 # 60 is reference by physics tick rate


var tick_length = 1.0 / Engine.physics_ticks_per_second

var buffer : Array = []
var interpolation_delay = tick_length * 4 # 4 game ticks delay
var curr_time : float = 0.0 # local clock

func _ready():
	if get_tree().root.get_node("Main").my_ID == 1:
		set_process(false)
	elif get_parent().is_multiplayer_authority(): # if this is a client-controlled entity (also not server)
		set_process(true)
	else:
		set_as_top_level(true) # because gonna be interpolated

var temp = 0.0
# called by player every time processes new update state
func update_states(statee):
	var state : Dictionary = statee.duplicate()
	state["timestamp"] = curr_time # time stamp it
	print(curr_time-temp)
	temp = curr_time
	buffer.push_back(state)
	while buffer.size() > 10:
		buffer.pop_front()
	

func _process(delta):
	# for non-server client-controlled entities
	# smooths offset between previous client-predicted and newly predicted states (based on new authority state)
	if !get_tree().root.get_node("Main").my_ID == 1 && is_multiplayer_authority():
		if position.length() < 2:
			position = Vector2(0,0)
			return
		position = position.lerp(Vector2(0,0), smoothing_factor * delta)
		return
	# else
	# non-server non-client-controlled entities
	# no client side prediction, larger jumps, use buffer to interpolate	
	curr_time += delta
	var render_time : float = curr_time - interpolation_delay # to check timestamps of buffer
	while buffer.size() > 2 && buffer[0]["timestamp"] < render_time:
		buffer.pop_front()
	
	if buffer.size() < 2:
		return
	
	var alpha = clamp((render_time - buffer[0]["timestamp"]) / (buffer[1]["timestamp"] - buffer[0]["timestamp"]), 0.0, 1.0)
	global_position = buffer[0]["position"].lerp(buffer[1]["position"], alpha)
