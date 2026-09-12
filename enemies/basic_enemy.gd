class_name BasicEnemy
extends CharacterBody2D
## 基础杂兵：待机 → 索敌 → 追击 → 攻击前摇（预警）→ 近战攻击 → 受击/死亡。

enum State { IDLE, CHASE, WINDUP }

@export var move_speed: float = 140.0
@export var detect_range: float = 360.0
@export var attack_range: float = 52.0
@export var attack_damage: float = 10.0
@export var windup_time: float = 0.55
@export var attack_cooldown: float = 0.8
@export var factor_id: String = "factor_rage"

var _base_color := Color(0.95, 0.3, 0.3)  # 占位回退色

@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Body
@onready var health_bar: HealthBar = $HealthBar

var state: State = State.IDLE
var _player: Player = null
var _windup_timer: float = 0.0
var _attack_cd: float = 0.0
var _slow_mult: float = 1.0
var _slow_timer: float = 0.0
var _fear_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	var tex := Art.enemy_mob(factor_id, RunManager.rng_randi_range(1, 5))
	if tex != null:
		Art.fit_sprite(body_sprite, tex, 40.0)
		_base_color = Color.WHITE
	else:
		body_sprite.texture = Placeholder.spiky(20, Color.WHITE)
	body_sprite.modulate = _base_color
	health_bar.set_value(health.hp / health.max_hp)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)

func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_slow_timer = maxf(0.0, _slow_timer - delta)
	if _slow_timer <= 0.0:
		_slow_mult = 1.0
	else:
		body_sprite.modulate = Color(0.6, 0.5, 1.0) if _fear_timer > 0.0 else Color(0.7, 0.8, 1.4)
	_fear_timer = maxf(0.0, _fear_timer - delta)
	match state:
		State.IDLE:
			_idle()
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			_windup(delta)

func _idle() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player != null and global_position.distance_to(_player.global_position) <= detect_range:
		state = State.CHASE

func _find_player() -> Player:
	var group := get_tree().get_nodes_in_group("player")
	return group[0] as Player if not group.is_empty() else null

func _chase(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		state = State.IDLE
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > detect_range * 1.4:
		state = State.IDLE
		return
	if dist <= attack_range:
		if _attack_cd <= 0.0:
			_begin_windup()
		return
	# 恐惧：逃离玩家；减速：移动放缓
	var dir := to_player.normalized()
	if _fear_timer > 0.0:
		dir = -dir
	velocity = dir * move_speed * _slow_mult * (0.6 if _fear_timer > 0.0 else 1.0)
	move_and_slide()

## 减速（惧因子命中效果）：slow_pct 为减速百分比，持续 time 秒。
func apply_slow(slow_pct: float, time: float) -> void:
	_slow_mult = clampf(1.0 - slow_pct, 0.2, 1.0)
	_slow_timer = maxf(_slow_timer, time)
	body_sprite.modulate = Color(0.7, 0.8, 1.4)

## 恐惧（战栗共鸣）：减速 50% 并逃离玩家 time 秒。
func apply_fear(time: float) -> void:
	_slow_mult = minf(_slow_mult, 0.5)
	_slow_timer = maxf(_slow_timer, time)
	_fear_timer = time
	body_sprite.modulate = Color(0.6, 0.5, 1.0)

func _begin_windup() -> void:
	state = State.WINDUP
	_windup_timer = windup_time
	velocity = Vector2.ZERO
	body_sprite.modulate = Color(1.6, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(body_sprite, "scale", Vector2(1.25, 1.25), windup_time)

func _windup(delta: float) -> void:
	_windup_timer -= delta
	if _windup_timer <= 0.0:
		_do_attack()

func _do_attack() -> void:
	body_sprite.scale = Vector2.ONE
	body_sprite.modulate = _base_color
	_attack_cd = attack_cooldown
	state = State.CHASE
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= attack_range * 1.5:
			CombatResolver.deal_damage(_player, attack_damage, self)

func take_damage(amount: float, _source: Node = null) -> void:
	health.take_damage(amount)

func _on_damaged(_amount: float, _new_hp: float) -> void:
	health_bar.set_value(health.hp / health.max_hp)
	body_sprite.modulate = Color(1.8, 1.8, 1.8)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _base_color, 0.12)

func _on_died() -> void:
	EventBus.emit("combat.entity_died", self)
	queue_free()
