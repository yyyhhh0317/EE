extends Node2D
## 测试房间（M2 因子与失控）：打怪掉精华 → 注射 → 词条 + 失控值 → 反噬/稳定剂。

const PLAYER_SCENE := preload("res://player/player.tscn")
const ENEMY_SCENE := preload("res://enemies/basic_enemy.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://combat/damage_number.tscn")
const PICKUP_SCENE := preload("res://combat/pickup.tscn")

const TARGET_ENEMY_COUNT := 6
const RESPAWN_DELAY := 1.2

@onready var enemies: Node2D = $Enemies
@onready var fx_layer: Node2D = $FxLayer
@onready var hp_label: Label = $UILayer/HUD/HP
@onready var instability_label: Label = $UILayer/HUD/InstabilityLabel
@onready var instability_bar: ProgressBar = $UILayer/HUD/InstabilityBar
@onready var essence_label: Label = $UILayer/HUD/EssenceLabel
@onready var status_label: Label = $UILayer/HUD/StatusLabel
@onready var unstable_warning: Label = $UILayer/HUD/UnstableWarning

var _player: Player = null
var _respawn_queue: Array[float] = []

func _ready() -> void:
	print("[TestRoom] 已进入测试房间（M2 因子与失控）。")
	EventBus.on("combat.damage_dealt", _on_damage_dealt)
	EventBus.on("combat.entity_died", _on_entity_died)
	EventBus.on("player.hp_changed", _on_player_hp_changed)
	EventBus.on("run.instability_changed", _on_instability_changed)
	EventBus.on("run.essence_changed", _on_essence_changed)
	EventBus.on("run.unstable_state_changed", _on_unstable_state_changed)
	_spawn_player()
	for i in TARGET_ENEMY_COUNT:
		_spawn_enemy()
	# 用当前 RunManager 状态初始化 HUD。
	_on_instability_changed(RunManager.instability)
	_on_essence_changed(RunManager.essence)
	_on_unstable_state_changed(RunManager.is_unstable)

func _process(delta: float) -> void:
	# 处理死亡后的重生计时。
	for i in range(_respawn_queue.size() - 1, -1, -1):
		_respawn_queue[i] -= delta
		if _respawn_queue[i] <= 0.0:
			_respawn_queue.remove_at(i)
			_spawn_enemy()
	_update_status()

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
	var dist := randf_range(200.0, 320.0)
	e.global_position = _player.global_position + Vector2.from_angle(angle) * dist

func _spawn_drop(pos: Vector2) -> void:
	var roll := randf()
	var type := "factor_rage"
	if roll < 0.4:
		type = "factor_rage"
	elif roll < 0.8:
		type = "factor_fear"
	else:
		type = "stabilizer"
	var p: Pickup = PICKUP_SCENE.instantiate()
	fx_layer.add_child(p)
	p.setup(type, pos)

func _update_status() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var rage := _player.mods.get_stacks("mod_rage_stack")
	var fear := _player.mods.get_stacks("mod_fear_speed")
	status_label.text = "怒叠层 %d · 惧叠层 %d · 攻击 %.0f · 移速 %.0f" % [
		rage, fear, _player.get_effective_attack(), _player.get_effective_move_speed(),
	]

## ---- 事件回调 ----
func _on_damage_dealt(payload: Dictionary) -> void:
	var target: Node = payload.get("target")
	var amount: float = payload.get("amount", 0.0)
	if not is_instance_valid(target):
		return
	var color := Color(1.0, 0.35, 0.35) if target.is_in_group("player") else Color(1.0, 0.95, 0.5)
	var num: Label = DAMAGE_NUMBER_SCENE.instantiate()
	fx_layer.add_child(num)
	num.setup(amount, target.global_position, color)

func _on_entity_died(enemy: Node) -> void:
	_respawn_queue.append(RESPAWN_DELAY)
	if is_instance_valid(enemy):
		# 物理回调（body_entered）期间不能同步 add 一个 Area2D，改为延迟生成。
		var pos: Vector2 = enemy.global_position
		_spawn_drop.call_deferred(pos)

func _on_player_hp_changed(hp: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	hp_label.text = "HP: %d/%d" % [int(hp), int(_player.health.max_hp)]

func _on_instability_changed(value: float) -> void:
	instability_bar.value = value
	instability_label.text = "失控值 %d/%d" % [int(value), int(RunManager.INSTABILITY_MAX)]

func _on_essence_changed(ess: Dictionary) -> void:
	essence_label.text = "怒精华 ×%d   惧精华 ×%d" % [
		int(ess.get("factor_rage", 0)), int(ess.get("factor_fear", 0)),
	]

func _on_unstable_state_changed(unstable: bool) -> void:
	unstable_warning.visible = unstable

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		GameManager.back_to_menu()
