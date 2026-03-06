extends Node


var my_ID = 1 #for instantiation

var main = null

var player_objects = {} # OWNED BY MAIN; empty for initialized will be overwritten by set_player_objects()
var objects = {} # OWNED BY MAIN 

######################################################################################################
##--------------------------------------   SETUP STUFF   ---------------------------------------------
######################################################################################################

func set_ID(id):
	my_ID = id

func set_player_objects(player_objectss):
	player_objects = player_objectss

func set_objects(objectss):
	objects = objectss

######################################################################################################
##------------------------------------   REST OF STUFF   ---------------------------------------------
######################################################################################################
func _ready():
	main = get_tree().root.get_node("Main")



#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvfvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
#from server main send out signal to start games to clients
func send_start_game():
	#peer id 0 means all peers besides self
	rpc_id(0, "recieve_start_game")

#recieve start game signal from server, tells client main to start game
@rpc("any_peer", "reliable")
func recieve_start_game():
	get_parent().start_game()
	
#called by server, send msg to end game to clients
func send_end_game():
	rpc_id(0, "recieve_end_game")

#client recieve msg from server to end game
@rpc("any_peer", "reliable")
func recieve_end_game():
	main.end_game()
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#called by server to send out msg to clients to delete a particular player bc dead prob
func send_delete_player(id):
	rpc_id(0, "recieve_delete_player", id)

@rpc("any_peer", "reliable")
func recieve_delete_player(id):
	get_parent().remove_player(id)


#called by host multiplayer_processing to send out updates for both player and object states
func send_states(states):
	rpc_id(0, "recieve_states", states)

@rpc("any_peer", "unreliable")
func recieve_states(states):
	for key in states:
		match key:
			"player_datas":
				var player_datas = states[key]
				for id in player_datas:
					# just checking if last_input_num for particular id is in dictionary
					# if player_object for said id available/valid, send data + last_inputs_num
					if player_objects.has(id) and is_instance_valid(player_objects[id]):
						player_objects[id].update_state(player_datas[id])
			"objects_datas":
				var objects_datass = states[key]
				for key2 in objects_datass:
					#handle new objects, creation
					if not objects.has(key2):
						var type = objects_datass[key2]["type"]
						match type:
							##"Sawblade":
							##	var obj = Scenes[type].instantiate()
							##	objects[key2] = obj
							##	add_child(obj)
							##"Boom":
							##	var obj = Scenes[type].instantiate()
							##	objects[key2] = obj
							##	add_child(obj)
							_: #else
								pass
					else:
						if is_instance_valid(objects[key2]):
							objects[key2].update_game_state(objects_datass[key2])
			"inputs_counter":
				pass # do nothing, handled before match case blockcuz needed earlier
			_:
				print("\'",key, "\' is unknown type of state sent server to client \'recieve_states\' in to_client")
	##7/30/2025 was when change was made
	##get_parent().update_player_datas(states["player_datas"])
	##get_parent().update_object_states(states["objects_datas"])
	##get_parent().currMap.task_board.update_states(states["task_elements_times"])
	##get_parent().get_node("Multiplayer_Tasks").recieve_process_update_task(states["task"])

#send info to delete object
func send_delete_objects(objects_to_be_deleted):
	if len(objects_to_be_deleted) > 0:
		rpc_id(0, "recieve_delete_objects", objects_to_be_deleted)

#recieve information to delete object
@rpc("any_peer", "reliable")
func recieve_delete_objects(objects_to_be_deleted):
	get_parent().client_delete_objects(objects_to_be_deleted)
