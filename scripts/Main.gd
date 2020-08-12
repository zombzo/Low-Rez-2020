extends Node2D

signal turn_start

onready var MonsterBase = load("res://Monster.tscn")
onready var ShopScreen = load("res://Shop.tscn")


var random = RandomNumberGenerator.new()
#var monsterSpawnList = ["spiritCouncil","spirit","spiritCouncil","spiritMage","spiritBoss"]
var monsterSpawnList = []
var CurrentMonster
export var power_level = 1

#Innkeeper Data
var IKhealth = 20
var IKhealth_full = IKhealth
var turn_count = 0
var previous_turn = 0
var damage = 0
var armor = 0
var IKcurrency = 2
var ailment = null
var currentAilment = null

# Called when the node enters the scene tree for the first time.
func _ready():
	initialize_innkeeper()
	set_Day()

func _process(delta):
	#Set the swap count remaining
	$UI/swap_icon/Label.text = str($ViewportContainer/Viewport/TileGrid.moves_remaining)
#	print(len(monsterSpawnList))
	#Once turn ends, monster goes. Right now it just uses a random attack amount from the MonsterDB.
	#Handle attacks as a dict that are then matched? Damage:3, Blocks: 5, Row:1, Heal:10 etc.


func set_Day():

	IKhealth = IKhealth_full
	armor = 0
	update_armor()
	$Background/Tavern.play("Morning")
	yield($Background/Tavern,"animation_finished")
	
	$Background/Tavern.play("MerchantEntrance")
	yield($Background/Tavern,"animation_finished")



	var Shop = ShopScreen.instance()
	Shop.currency = IKcurrency
	Shop.connect("shop_closed", self, "_on_shop_closed")
	Shop.connect("update_currency", self, "_on_currency_updated")
	$ViewportContainer/Viewport/TileGrid.set_mouse_input(Control.MOUSE_FILTER_IGNORE)
	self.add_child(Shop)

func set_Night():
	
	#Make Merchant Leaving animation
	IKhealth_full = IKhealth
	
	
	$Background/Tavern.play("Night")
	yield($Background/Tavern,"animation_finished")
	
	monsterSpawnList = MonsterDB.get_level_list(power_level).duplicate(true)
	
	spawn_monster(monsterSpawnList[0])
	monsterSpawnList.pop_front()

func _on_shop_closed():
	$ViewportContainer/Viewport/TileGrid.set_mouse_input(Control.MOUSE_FILTER_STOP)
	set_Night()
	emit_signal("turn_start")
	
func _on_currency_updated(currency):
	IKcurrency = currency
	$UI/Currency/Label.text = str(IKcurrency)
	
func initialize_innkeeper():
	$UI/health_icon/InnkeeperHealth.text = str(IKhealth)
	$UI/Currency/Label.text = str(IKcurrency)
	update_armor()

func spawn_monster(value):
	$UI/swap_icon/Label.add_color_override("font_color", Color("fbf236"))
	var Monster = MonsterBase.instance()
	Monster.id = value
	Monster.connect("monster_dead",self,"monster_died")
	$MonsterSpawn.add_child(Monster)
	CurrentMonster = $MonsterSpawn.get_child(0)
	

func monster_died(currency):
	$MonsterSpawn.get_child(0).queue_free()
	IKcurrency = min(currency+IKcurrency,99)
	$UI/Currency/Label.text = str(IKcurrency)
	if len(monsterSpawnList)>0:
		#TODO: Get which monsters spawn and then determine a random new one up. Could do a random order to balance?
		spawn_monster(monsterSpawnList[0])
		monsterSpawnList.pop_front()
		CurrentMonster = $MonsterSpawn.get_child(0)
	else:
		CurrentMonster = null
		power_level += 1
		set_Day()

func update_IK_health(amount):
	var leftover_dmg = max(amount - armor,0)
	armor = max(armor-amount,0)
	update_armor()
	IKhealth = IKhealth - leftover_dmg
	$UI/health_icon/InnkeeperHealth.text = str(IKhealth)
	maybe_IK_dead()

func update_armor():
	if armor <= 0:
		$UI/armor_icon.visible = false
	else:
		$UI/armor_icon.visible = true
		$UI/armor_icon/Label.text = str(armor)
	
func maybe_IK_dead():
	if IKhealth <= 0:
		get_tree().paused = true
		var gameOver = load("res://GameOverScreen.tscn").instance()
		add_child(gameOver)

func _on_TileGrid_turn_ended(activations):
	CurrentMonster = $MonsterSpawn.get_child(0)
	#Handle tile type and activation:
	for i in activations:
		if i["tileType"] == "empty":
			continue
		
		set_activated_tiles(i.activated_tiles)
		yield(get_tree().create_timer(1.5), "timeout")
		match i["tileType"]:
			"autoAttack":
				damage += i["length"] * 1
				print("autoAttack for " + str(damage))
			"fire":
				damage += i["length"] * 2
				print("fire for " + str(damage))
			"earth":
				var new_armor = i["length"] * 1
				#INSERT: Animation for max armor
				armor = min(new_armor + armor,9)
				print("armor for " + str(new_armor))
				
		#User deals damage
		$MonsterSpawn.get_child(0).update_health(max(damage-CurrentMonster.blockAmount,0))
		damage = 0
		update_armor()
		unset_activated_tiles(i.activated_tiles)
		
	previous_turn = turn_count
	turn_count += 1
	
	if CurrentMonster:
		if CurrentMonster.Health > 0:
			monster_turn()
			
	clear_tile_shader_params()
	
	emit_signal("turn_start")
	
	if ailment:
		currentAilment = ailment
		var i = 5
		var array : Array = []
		var TileOG = $ViewportContainer/Viewport/TileGrid.tiles
		var TilesVec = TileOG.duplicate(true)
		TilesVec = TilesVec[0]+TilesVec[1]+TilesVec[2]


		while i != 0:
			random.randomize()
			var randNum = random.randi_range(0,len(TilesVec)-1)
			if TilesVec[randNum]["tileType"] != "item":
				print(TilesVec[randNum]["tileType"])
				array.append(TilesVec[randNum]["button"])
				TilesVec.remove(randNum)
				i -= 1

		match ailment:
			"Shade":
				for node_name in array:
					var c = $ViewportContainer/Viewport/TileGrid.get_children()[$ViewportContainer/Viewport/TileGrid.get_children().find(node_name)]
					c.material.set_shader_param("isShade", true)
			"Slime":
				for node_name in array:
					var c = $ViewportContainer/Viewport/TileGrid.get_children()[$ViewportContainer/Viewport/TileGrid.get_children().find(node_name)]
					c.material.set_shader_param("isSlimed", true)
		
		
		ailment = null
	#HandDealt -> Ailment takes effect -> Animation of hand dealt

func set_activated_tiles(tiles):
	for tile in tiles:
		$ViewportContainer/Viewport/TileGrid.tiles[tile.x][tile.y].button.get_material().set_shader_param("isActivated", true)

func unset_activated_tiles(tiles):
	for tile in tiles:
		$ViewportContainer/Viewport/TileGrid.tiles[tile.x][tile.y].button.get_material().set_shader_param("isActivated", false)

func monster_turn():
	$UI/swap_icon/Label.add_color_override("font_color", Color("fbf236"))
	print(CurrentMonster)
	CurrentMonster = $MonsterSpawn.get_child(0)
	print(CurrentMonster)
	match CurrentMonster.current_move_type:
		"Damage":
			update_IK_health(CurrentMonster.current_move_value)
		"Shade":
			ailment = "Shade"
		"Slime":
			ailment = "Slime"
		"Rage":
			CurrentMonster.rage = true	
		"Heal":
			CurrentMonster.update_health(-CurrentMonster.current_move_value)
		"Frost":
			$ViewportContainer/Viewport/TileGrid.frost = true
			$UI/swap_icon/Label.add_color_override("font_color", Color("1bdddd"))
		"Mirror":
			update_IK_health(CurrentMonster.mirror_damage)
		"Block":
			pass #handled in the mosnter script
	CurrentMonster.next_attack()
	previous_turn = turn_count

func clear_tile_shader_params():
	for tile in $ViewportContainer/Viewport/TileGrid.get_children():
		tile.get_material().set_shader_param("isShade", false)
		tile.get_material().set_shader_param("isSlimed", false)

func _on_TileGrid_move_occured():
	if currentAilment == "Shade":
		clear_tile_shader_params()
