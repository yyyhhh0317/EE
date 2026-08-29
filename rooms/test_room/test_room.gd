extends Node2D
## 测试房间（M1 战斗原型）：玩家 + 无限刷怪，验证移动/发射/伤害/命中反馈。

const PLAYER_SCENE := preload("res://player/player.tscn")
const ENEMY_SCENE := preload("res://enemies/basic_enemy.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://combat/damage_number.tscn")

const TARGET_ENEMY_COUNT := 6
const RESPAWN_DELAY := 1.2

@onready var enemies: Node2D = $Enemies
@onready var fx_layer: Node2D = $FxLayer
@onready var hp_label: Label = $UILayer/HUD/HP

var _player: Player = null
var _respawn_queue: Array[float] = []

func _ready() -> void:
	print("[TestRoom] 已进入测试房间（M1 战斗原型）。")
	EventBus.on("combat.damage_dealt", _on_damage_dealt)
	EventBus.on("combat.entity_died", _on_entity_died)
	EventBus.on("player.hp_changed", _on_player_hp_changed)
	_spawn_player()
	for i in TARGET_ENEMY_COUNT:
		_spawn_enemy()

func _process(delta: float) -> void:
	# 处理死亡后的重生计时。
	for i in range(_respawn_queue.size() - 1, -1, -1):
		_respawn_queue[i] -= delta
		if _respawn_queue[i] <= 0.0:
			_respawn_queue.remove_at(i)
			_spawn_enemy()

func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.global_position = Vector2.ZERO
	hp_label.text = "HP: %d/%d" % [int(_player.health.hp), int(_player.health.max_hp)]

func _spawn_enemy() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var e: BasicEnemy = ENEMY_SCENE.instantiate()
	enemies.add_child(e)
	var angle := randf() * TAU
	var dist := randf_range(150.0, 300.0)
	e.global_position = _player.global_position + Vector2.from_angle(angle) * dist

func _on_damage_dealt(payload: Dictionary) -> void:
	var target: Node = payload.get("target")
	var amount: float = payload.get("amount", 0.0)
	if not is_instance_valid(target):
		return
	var color := Color(1.0, 0.35, 0.35) if target.is_in_group("player") else Color(1.0, 0.95, 0.5)
	var num: Label = DAMAGE_NUMBER_SCENE.instantiate()
	fx_layer.add_child(num)
	num.setup(amount, target.global_position, color)

func _on_entity_died(_payload: Variant) -> void:
	_respawn_queue.append(RESPAWN_DELAY)

func _on_player_hp_changed(hp: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	hp_label.text = "HP: %d/%d" % [int(hp), int(_player.health.max_hp)]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameManager.back_to_menu()
