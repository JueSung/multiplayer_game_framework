extends Node
class_name Multiplayer_Processing

var my_ID
var clock = 0.0 # clock
var tick_length = 1.0/Engine.physics_ticks_per_second # speed that information gets sent out to clients

var players_IDs = [] #for host, #in order as joined from host perspective
var players_inputs = {} #dictionary of player id : dictionary of inputs
var player_datas = {}
var player_objects = {} # OWNED BY MAIN, empty for initialization, is reassigned via reference/alias to main's dictionary
var objects = {} # OWNED BY MAIN

var objects_datas = {}
var objects_to_be_deleted = []

var clientToServerInfo = {}

#player_datas + objects_datas + players_last_inputs_num (ordering number)
var states = {
} 

######################################################################################################
##--------------------------------------   SETUP STUFF   ---------------------------------------------
######################################################################################################

# called by upon_join() called by Lobby
func set_id(id):
	my_ID = id
	
	if my_ID == 1:
		set_process(true)
	$ToClient.set_ID(id)
	$ToServer.set_ID(id)

func set_player_objects(player_objectss):
	player_objects = player_objectss
	
	$ToClient.set_player_objects(player_objects)
func set_objects(objectss):
	objects = objectss
	
	$ToClient.set_objects(objects)


######################################################################################################
##------------------------------------   REST OF STUFF   ---------------------------------------------
######################################################################################################

func _ready():
	$Lobby.player_loaded.rpc_id(1)
	
	# assign children nodes appropriate alias variables
	$ToServer.set_players_inputs(players_inputs)
	
	#initialize process to be not run, when set id, id = 1 will have process running
	set_process(false)

# called by Lobby when joining a host
func upon_join(peer_id):
	get_parent().upon_join(peer_id)
	set_id(peer_id)


#recieved from lobby _register_player when player joins both server and clients
func register_player(peer_id, _player_info):
	players_IDs.append(peer_id)
	
	get_parent().add_player(peer_id)

#signal recieved from lobby _on_player_disconnected if any peer disconnecs
func player_disconnected(peer_id):
	players_IDs.remove_at(players_IDs.find(peer_id))
	players_inputs.erase(peer_id)
	
	get_parent().remove_player(peer_id)
	remove_player(peer_id)

func remove_player(peer_id):
	player_datas.erase(peer_id)
	if my_ID == 1:
		$ToClient.send_delete_player(peer_id)

#for client when/if server disconnects -- called by 
func server_disconnected():
	return_to_title_page()

func start_game():
	if my_ID == 1:
		$ToClient.send_start_game()
	else:
		get_parent().start_game()
	
func end_game():
	objects_datas = {}
	# player_datas = {}
	
	if my_ID == 1:
		$ToClient.send_end_game()
	

func return_to_title_page():
	get_parent().return_to_title_page()
	player_datas = {}
	players_inputs = {}
	players_IDs = []
	objects_datas = {}

func get_players_inputs():
	return players_inputs

var network_timer = 0.0
#only runs if my_ID == 1 - serverside
func _process(delta):
	clock += delta
	network_timer += delta
	if network_timer > tick_length * 3: # send only every 3 ticks
		network_timer -= tick_length * 3
		# update player_objects input values
		for id in player_objects: #enhanced for loop
			#if id in players_inputs:
				#player_objects[id].update_inputs(players_inputs[id])
			# update player_datas
			player_datas[id] = player_objects[id].get_state()
		
		if get_parent().is_inGame(): # CHANGE possibly not make is_inGame for in game lobby
			var objects = get_parent().get_objects()
			# update object datas from objects
			for key in objects:
				if is_instance_valid(objects[key]):
					objects_datas[key] = objects[key].get_state()
			
		#$Multiplayer_Processing.send_object_states(objects_datas) #handles objects to be added via seeing new objects
		states["player_datas"] = player_datas
		states["objects_datas"] = objects_datas
		#var inputs_counters = {}
		#for id in players_inputs:
		#	inputs_counters[id] = players_inputs[id]["counter"]
		#states["inputs_counter"] = inputs_counters.duplicate() # input ordering number from clients
			
		$ToClient.send_delete_objects(objects_to_be_deleted)
		objects_to_be_deleted = []
		$ToClient.send_states(states)

# ran by clients::_____________________
##func update_player_datas(player_datass):
##	player_datas = player_datass	
##	for id in player_datas:
##		if player_objects.has(id) and is_instance_valid(player_objects[id]):
##			player_objects[id].update_state(player_datass[id])
	
## func update_object_states(objects_datass):
##	for key in objects_datass:
##		#handle new objects, creation
##		if not objects.has(key):
##			var type = objects_datass[key]["type"]
##			match type:
##				##"Sawblade":
##				##	var obj = Scenes[type].instantiate()
##				##	objects[key] = obj
##				##	add_child(obj)
##				##"Boom":
##				##	var obj = Scenes[type].instantiate()
##				##	objects[key] = obj
##				##	add_child(obj)
##				_: #else
##					pass
##		else:
##			if is_instance_valid(objects[key]):
##				objects[key].update_game_state(objects_datass[key])

#only for clients # not sure if works bc if enhanced for loop gets messed up when you delete during
func client_delete_objects(objects_to_be_deletedd):
	var objects = get_parent().get_objects()
	for i in range(len(objects_to_be_deletedd)):
		var key = objects_to_be_deletedd[i]
		if objects.has(key) and is_instance_valid(objects[key]):
			get_parent().remove_object(key)
			objects_datas.erase(key)
		
func get_time():
	return clock
