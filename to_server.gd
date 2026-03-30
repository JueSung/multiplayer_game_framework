extends Node

var my_ID = 1 #for instantiation
var inputs = {
	"counter" : -1, # refers to ordering in client
	"left" : false,
	"right" : false,
	"up" : false,
	"down" : false,
	"left_click" : false,
	"right_click" : false,
	"mouse_position_x" : 0,
	"mouse_position_y" : 0
}
var players_inputs = {} # for host side, defined in by alias setup, owned by multiplayer_processing
var inputs_queue = [] # queue of inputs's
var inputs_counter = 0 # int value for keeping track order of input setes

var clientToServerInfo = {}

var network_timer = 0.0 # use to check tick speed stuff
var tick_length = 1.0/Engine.physics_ticks_per_second

######################################################################################################
##--------------------------------------   SETUP STUFF   ---------------------------------------------
######################################################################################################
func set_ID(id):
	my_ID = id
	
	# first time running after launch, process already running, but if disconnect, then will turn off from main
	# so when rejoin, need to have process run again
	set_process(true)

func set_players_inputs(players_inputss):
	players_inputs = players_inputss

######################################################################################################
##------------------------------------   REST OF STUFF   ---------------------------------------------
######################################################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
	inputs["counter"] = -1
	inputs["left"] = false
	inputs["right"] = false
	inputs["up"] = false
	inputs["down"] = false
	inputs["left_click"] = false
	inputs["right_click"] = false
	inputs["mouse_position_x"] = 0
	inputs["mouse_position_y"] = 0

# used by players/ client controlled entities
func get_inputs_queue():
	return inputs_queue
	
# used by player node on server side
func get_server_inputs(id):
	if not players_inputs.has(id):
		players_inputs[id] = {
		"counter" : -1,
		"left" : false,
		"right" : false,
		"up" : false,
		"down" : false,
		"left_click" : false,
		"right_click" : false,
		"mouse_position_x" : 0,
		"mouse_position_y" : 0
		}
	return players_inputs[id]

# inputs sampled as fast as possible, if at least one of input sets before being sent is true, then its true
# in the combined set when sent to server, reset after sent.
func _process(delta):
	
	# only send every tick_length:
	network_timer += delta
	if network_timer >= tick_length:
		inputs["counter"] = inputs_counter
		append_client_to_server_info("inputs", inputs.duplicate())
		inputs_queue.append(inputs.duplicate())
		inputs_counter += 1
		
		#every frame calls send info to server
		process_send_to_server()
		
		# reset inputs # this must occur before input collection so within one _process tick, inputs get set and are not left as zero
		inputs["left"] = false
		inputs["right"] = false
		inputs["up"] = false
		inputs["down"] = false
		inputs["left_click"] = false
		inputs["right_click"] = false
		
		network_timer -= tick_length
	
	#set inputs----------- sets are or'ed with previous and reset every time whole thing saved
	inputs["left"] = Input.is_action_pressed("left") or inputs["left"]
	inputs["right"] = Input.is_action_pressed("right") or inputs["right"]
	inputs["up"] = Input.is_action_pressed("up") or inputs["up"]
	inputs["down"] = Input.is_action_pressed("down") or inputs["down"]
	inputs["left_click"] = Input.is_action_pressed("left_click") or inputs["left_click"]
	inputs["right_click"] = Input.is_action_pressed("right_click") or inputs["right_click"]

	inputs["mouse_position_x"] = get_viewport().get_mouse_position().x
	inputs["mouse_position_y"] = get_viewport().get_mouse_position().y
	#-----------------------------------------------------------------------
	
	

func get_inputs():
	return inputs

#add data to dictionary sorted by type and during process will send to server
func append_client_to_server_info(type, info):
	match type:
		"inputs":
			clientToServerInfo[type] = info
		_:
			print("unknown data type for sending to host")

####################################################################################################
# GENERALIZED SEND/RECIEVE PROCESS_DATA FROM CLIENT TO HOST-----------------------------------------
####################################################################################################

#generalized send info to server where info is a dictionary updated and reset every frame in main
func process_send_to_server():
	clientToServerInfo["id"] = my_ID
	if my_ID != 1:
		rpc_id(1, "process_recieve_from_client", clientToServerInfo)
	else:
		process_recieve_from_client(clientToServerInfo)
	#resets so info doesn't just get held there forever
	clientToServerInfo = {}

# server recieve process data from client and call appropriate functions based on types of data
@rpc("any_peer", "unreliable")
func process_recieve_from_client(info):
	for type in info:
		match type:
			"id":
				pass # do nothing used for identifying what client it is and stuff
			"inputs":
				recieve_client_inputs(info["id"], info["inputs"])	
			_:
				print("unknown process info sent to server from client sent: ", type)
####################################################################################################
#---------------------------------------------------------------------------------------------------
####################################################################################################

#recieving client inputs from client Main
func recieve_client_inputs(id, inputss):
	# doesn't overwrite player_inputs[id] so any alias remain intact
	if not players_inputs.has(id):
		players_inputs[id] = {
		"counter" : -1,
		"left" : false,
		"right" : false,
		"up" : false,
		"down" : false,
		"left_click" : false,
		"right_click" : false,
		"mouse_position_x" : 0,
		"mouse_position_y" : 0
		}
	for key in inputss:
		players_inputs[id][key] = inputss[key]
	
