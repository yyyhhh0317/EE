class_name BossEnemy
extends CharacterBody2D
## 章末 Boss（狂暴巨人）：追近 → 前摇预警 → 冲刺撞击，接触造成伤害。

enum State { CHASE, WINDUP, CHARGE, RECOVER }

@export var move_speed: float = 110.0
@export var charge_speed: float = 430.0
@export var melee_range: float = 80.0
@export var charge_damage: float = 24.0
@export var windup_time: float = 0.6
@export var charge_time: float = 0.5
@export var recover_time: float = 0.5
@export var attack_cooldown: float = 1.3

var _base_color := Color(0.85, 0.15, 0.2)

@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Body
@onready var health_bar: HealthBar = $HealthBar

var state: State = State.CHASE
var _player: Player = null
var _timer: float = 0.0
var _attack_cd: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	body_sprite.texture = Placeholder.circle(34, Color.WHITE)
	body_sprite.modulate = _base_color
	health_bar.set_value(health.hp / health.max_hp)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)

func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	match state:
		State.CHASE:
			_chase()
		State.WINDUP:
			_windup(delta)
		State.CHARGE:
			_charge(delta)
		State.RECOVER:
			_recover(delta)

func _find_player() -> Player:
	var group := get_tree().get_nodes_in_group("player")
	return group[0] as Player if not group.is_empty() else null

func _chase() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist <= melee_range and _attack_cd <= 0.0:
		_begin_charge(to_player.normalized())
		return
	velocity = to_player.normalized() * move_speed
	move_and_slide()

func _begin_charge(dir: Vector2) -> void:
	state = State.WINDUP
	_timer = windup_time
	_charge_dir = dir
	velocity = Vector2.ZERO
	body_sprite.modulate = Color(2.0, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(body_sprite, "scale", Vector2(1.3, 1.3), windup_time)

func _windup(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		body_sprite.scale = Vector2.ONE
		body_sprite.modulate = Color(3.0, 0.8, 0.8)
		state = State.CHARGE
		_timer = charge_time

func _charge(delta: float) -> void:
	_timer -= delta
	velocity = _charge_dir * charge_speed
	move_and_slide()
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= 46.0:
			CombatResolver.deal_damage(_player, charge_damage, self)
			_end_charge()
	if _timer <= 0.0:
		_end_charge()

func _end_charge() -> void:
	body_sprite.modulate = _base_color
	body_sprite.scale = Vector2.ONE
	velocity = Vector2.ZERO
	state = State.RECOVER
	_timer = recover_time
	_attack_cd = attack_cooldown

func _recover(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state = State.CHASE

func take_damage(amount: float, _source: Node = null) -> void:
	health.take_damage(amount)

func _on_damaged(_amount: float, _new_hp: float) -> void:
	health_bar.set_value(health.hp / health.max_hp)
	body_sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _base_color, 0.12)

func _on_died() -> void:
	EventBus.emit("combat.entity_died", self)
	queue_free()
