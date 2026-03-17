extends CharacterBody2D
class_name Player
#set camera zoom to .7

var main = null
var my_ID # id of the client that owns this player, not of main, matches with is_multiplayer_authority()
# time delta of game tick speed aka speed of sending clients updated game state information
var tick_length = 1.0/Engine.physics_ticks_per_second
var catching_up = false # set to true in update_state when doing catch up, tells physics_process not to simulate
var smoothing_factor = 0.15 # for catch up, less jitter

const SPEED = 840
const GRAVITY = 3000

var JUMP_VELOCITY = -1 * sqrt(GRAVITY * 2 * 240)

var on_floor = false

#user input info ---------
var left = false
var right = false
var up = false
var down = false
var left_click = false
var right_click = false
var mouse_position = Vector2(0,0)
#-------------------------

# client: set to ToServer inputs var as alias for client side real-time response
# server: set to ToServer player_inputs[id] for game state calculation based on recieved client inputs
var inputs = {
	"counter" : -1,
	"left" : false,
	"right" : false,
	"up" : false,
	"down" : false,
	"left_click" : false,
	"right_click" : false,
	"mouse_position_x" : 0.0,
	"mouse_position_y" : 0.0
} 


var inputs_queue = [] # used for client side prediction catch up
var state = {
	"position" : Vector2(0.0, 0.0),
	"rotation" : 0.0,
	"on_floor" : false,
	"velocity" : Vector2(0.0, 0.0),
	
	"counter" : -1
}
var prev_state = { # used as temp holder for reconcilliation_offset calculation
	"position" : Vector2(0.0, 0.0),
}
# offsets for reconcillation with authority state, lerped at exponential rate
var reconcilliation_offset = {
	"position" : Vector2(0.0, 0.0),
	"rotation" : 0.0
	}

func set_ID(id):
	my_ID = id


func _ready():
	main = get_tree().root.get_node("Main")
	set_process(false)
	
	
	if main.my_ID != 1 and not is_multiplayer_authority(): # is client and doesn't control this player
		set_physics_process(false)
		# we only update position based on update_state when recieved from server
		
		## $CollisionShape2D.disabled = true # need hitboxes on for client side prediction
		
	else:
		
		
		
		if is_multiplayer_authority():
			inputs = main.get_node("Multiplayer_Processing").get_node("ToServer").get_inputs()
			inputs_queue = main.get_node("Multiplayer_Processing").get_node("ToServer").get_inputs_queue()
			
		if main.my_ID == 1:
			# server inputs used for game calculation ran by server
			inputs = main.get_node("Multiplayer_Processing").get_node("ToServer").get_server_inputs(my_ID)
		
		state["position"] = global_position
		state["rotation"] = global_rotation
		state["on_floor"] = false
		state["velocity"] = velocity
		state["counter"] = -1
		

# we use physics_process as both server side calculation and client side prediction because although we would ideally
# use _process for client-side prediction, move_and_slide() does not work because it uses internal delta value
# and even if it didn't since its not like a euler integrator, having a different delta will lead to diverging
# and would not work well kind of like double pendulums in chaos theory like it would not go well
func _physics_process(delta):
	if catching_up:
		return
	
	_game_calculation(delta, inputs) # game calculation
	
	# update state data structure on server of current states to send out to clients
	
		
	state["position"] = global_position
	state["rotation"] = global_rotation
	state["on_floor"] = on_floor
	state["velocity"] = velocity
	if main.my_ID == 1:
		state["counter"] = inputs["counter"] # for client-side prediction/catch up, this set of inputs have been processed

	
func _game_calculation(delta, inputss):
	var direction_x = 0
	#left, right
	if inputss["right"]:
		direction_x += 1
	if inputss["left"]:
		direction_x -= 1
	
	if not on_floor:
		if velocity.y <= 0 || inputss["up"]:
			velocity.y += GRAVITY * delta
		else:
			velocity.y += GRAVITY * 1.5 * delta
	else:
		velocity.y = 0
		
	if inputss["up"] and on_floor:
		velocity.y = JUMP_VELOCITY
	elif not inputss["up"] and not on_floor and velocity.y < 0:
		velocity.y -= (5 * velocity.y) * delta # used for variable jump heights depending on length of time holding jump button
		
	
	velocity.x = move_toward(velocity.x, direction_x * SPEED, SPEED * delta * 30)
	##if direction:
	##	direction = direction.normalized()
	##	velocity = velocity.move_toward(direction * SPEED, SPEED * delta * 30)
	##else:
	##	velocity.x = move_toward(velocity.x, 0, 20 * SPEED * delta)
		
	#position += velocity * delta
	move_and_slide()
	
	on_floor = is_on_floor()
	
	# smoothing error from client catch up
	# does not occur during catch-up phase after snapping to authority
	if not catching_up:
		for key in reconcilliation_offset:
			match key:
				"position":
					var correction = reconcilliation_offset[key]  * smoothing_factor
					global_position += correction
					reconcilliation_offset[key] -= correction
				"rotation":
					var correction = reconcilliation_offset[key]  * smoothing_factor
					global_rotation += correction
					reconcilliation_offset[key] -= correction
				_:
					print("Dunno what this reconcilliation_offset smoothing thingy is check game_calculation: ", key)
				
	
	
func get_state():
	return state

# recieve new state from server, need to snap to new authoritative state, and predict for all sets of inputs after last_input_num
func update_state(authority_state):
	if not is_multiplayer_authority():
		for key in authority_state:
			match key:
				"position":
					# usually using target_state for lerping
					global_position = authority_state[key]
					state["position"] = authority_state[key]
				"rotation":
					global_rotation = authority_state[key]
					state["rotation"] = authority_state[key]
				"on_floor":
					pass
				"velocity":
					pass # uneeded for rendering
				"counter":
					pass # only used for is_multiplayer_authority

				_:
					print("player object update state, unknown state type")
		return
	
	if my_ID == 1: # if server but also player-owned we don't need to reconcile
		return
		
	
	# now for client side prediction
	
	# set all states according to the authority_state
	var inputs_counter = -1
	
	for key in authority_state:
		match key:
			"position":
				prev_state[key] = global_position
				global_position = authority_state[key]
			"rotation":
				prev_state[key] = rotation
				rotation = authority_state[key]
			"on_floor":
				on_floor = authority_state[key]
			"velocity": # not smoothed
				velocity = authority_state[key]
			"counter":
				inputs_counter = authority_state[key]
			_:
				print("dunno authority_state type: ", key, "check update_state in player function")
	
	move_and_slide() # for desync stuff on_floor() stuff
	
	# step 1: remove all unnecessary saved input sets (the ones occured before the authority state that's now been recieved
	while len(inputs_queue) > 0 && inputs_queue[0]["counter"] <= inputs_counter:
		inputs_queue.remove_at(0) # pop off input that occured before this recieved state was processed
	
	# we let it still run even if no inputs, so that way reconcilliation offset is calculated to smooth out after snap
	#if len(inputs_queue) == 0:
	#	return
	
	
	# step2: apply input sets that occured after authority state time to predict current state using fixed tick rate
	
	catching_up = true
	
	for i in range(len(inputs_queue)):
		# else apply inputs and run appropriate _game_calculation function for fixed tick length
		# need to run calculation to catch up
		_game_calculation(tick_length, inputs_queue[i])
	
	# for smoothing in _game_calculation: state + reconcilliation_offset * some_fraction, then decr reconcilliation_offset
	for key in reconcilliation_offset:
		match key:
			"position":
				reconcilliation_offset[key] = global_position - prev_state[key]
				global_position = prev_state[key]
			"rotation":
				reconcilliation_offset[key] = global_rotation - prev_state[key]
				global_rotation = prev_state[key]

			_:
				print("EYYY what this reconcilation_offset check update_state")
	
	catching_up = false
	
