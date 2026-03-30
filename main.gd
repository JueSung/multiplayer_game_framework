extends Node
class_name Main

var my_ID = 1 #for instantiation


var player_objects = {}


var objects = {}

var objects_to_be_deleted = []


var PlayerScene = preload("res://player.tscn")
var MapScene = preload("res://map.tscn")

#For client instantiation scenes
var Scenes = {
	#"Sawblade" : preload("res://sawblade.tscn"),
	#"Boom" : preload("res://boom.tscn")
}

var inGame = false #if in a game, is true

var currMap = null
var sound_percentage = 100

func _ready():
	#$HUD.show()
	Engine.time_scale = 1
	
	# sets player_objects variable in multiplayer_processing to the same one as main via alias
	$Multiplayer_Processing.set_player_objects(player_objects)
	$Multiplayer_Processing.set_objects(objects)

func upon_join(peer_id):
	set_ID(peer_id)
	
	#initialize map upon joining
	var map = MapScene.instantiate()
	add_child(map)
	currMap = map


#called by Multiplayer_Processing by Lobby sets self either to 1 or the randomly generated id if not host
func set_ID(id):
	my_ID = id
	
	if my_ID == 1:
		set_process(true)

#recieved from multiplayer_processing from lobby _register_player when player joins both server and clients
#also already runs for self
func add_player(peer_id):
	var player_instance = PlayerScene.instantiate()
	player_instance.set_ID(peer_id)
	player_instance.set_multiplayer_authority(peer_id)
	
	#figure out player position, may be handled by Map in the future
	if my_ID == 1:
		# do some calculation to figure out placements of players
		player_instance.position = Vector2(300 + len(player_objects) * 100,300)
	else:
		#just yeet them up there, their positions will be updated shortly
		player_instance.position = Vector2(500, 540)

	player_objects[peer_id] = player_instance
	add_child(player_instance)
	
#homepage stuff
func host_game():
	$Multiplayer_Processing/Lobby.create_game()
	$HUD.host_game()
	

func join_game():
	if $HUD/IP.text == "" or $HUD/Port.text == "": #needs to enter ip/port info still
		$HUD.enter_ip_info()
	else:
		$HUD.join_game()
		var ip = $HUD/IP.text
		var port = $HUD/Port.text
		$Multiplayer_Processing/Lobby.join_game(ip, port)
		

func start_game():
	$HUD.start_game()
	inGame = true
	
	if my_ID == 1:
		$Multiplayer_Processing.start_game()
	currMap.start_game()
	

func return_to_title_page():
	inGame = false
	
	for id in player_objects:
		player_objects[id].queue_free()
	player_objects.clear()
	
	
	for id in objects:
		objects[id].queue_free()
	objects.clear()
	
	objects_to_be_deleted = []
	
	if currMap != null:
		currMap.queue_free()
		currMap = null

	
	$Multiplayer_Processing/Lobby.remove_multiplayer_peer()
	# set process of multiplayer_processing and to_server to false so not tryin to rpc while not even having any
	# multiplayer connection
	$Multiplayer_Processing.set_process(false)
	$Multiplayer_Processing/ToServer.set_process(false)
	$HUD.return_to_title_page()

#generally called by multiplayer_processing to get player objects
func get_player_objects():
	return player_objects
	
func get_objects():
	return objects

func is_inGame():
	return inGame

#possibly signal recieved from multiplayer_processing from lobby _on_player_disconnected if any peer disconnecs
#or called either by client from msg from server or part of server game state
func remove_player(id):
		
	if player_objects.has(id):
		player_objects[id].queue_free()
		player_objects.erase(id)
	
		## if my_ID == 1:
		## 	if len(player_objects) <= 1: # END GAME CONDITION CHANGE
		##		end_game()
#
func end_game():
	#send msg to end game
	if not inGame:
		return
		
	inGame = false
	
	$Multiplayer_Processing.end_game()

	
	#currMap.queue_free()
	#currMap = null
	
	#for id in player_objects:
	#	player_objects[id].queue_free()
	#player_objects.clear()
	#player_datas.clear()
	
	#players_inputs.clear()
	
	for id in objects:
		objects[id].queue_free()
	objects.clear()
	objects_to_be_deleted = []
	
	$HUD.visible = true
	if my_ID == 1:
		$HUD.host_game()
	else:
		$HUD.join_game()

# CLIENT ONLY called by multiplayer_processing
func remove_object(key):
	objects[key].queue_free()
	objects.erase(key)
