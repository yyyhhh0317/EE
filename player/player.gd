class_name Player
extends CharacterBody2D
## 玩家（零号受试者）：俯视角走位 + 鼠标瞄准 + 因子能量发射 + 冲刺（无敌帧）。
## M2 新增：词条系统（ModifierSystem）+ 因子注射 + 失控反噬。

@export var move_speed: float = 220.0
@export var fire_rate: float = 0.15
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 600.0
@export var dash_speed: float = 620.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.5

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")
const TICK_INTERVAL := 1.0  # on_tick 行为钩子触发间隔（秒）

var _base_color := Color(0.35, 0.8, 0.95)  # 正常 tint（真实素材时为白）
var _front_tex: Texture2D
var _back_tex: Texture2D
var _aim_dir := Vector2.RIGHT

var mods: ModifierSystem

@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Body
@onready var muzzle: Sprite2D = $Muzzle
@onready var camera: Camera2D = $Camera2D

var _fire_cd: float = 0.0
var _dash_cd: float = 0.0
var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _invincible_timer: float = 0.0
var _tick_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	mods = ModifierSystem.new()
	_apply_art()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_health_died)
	EventBus.on("run.injected", _on_injected)
	EventBus.on("run.unstable_state_changed", _on_unstable_state_changed)

func _physics_process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invincible_timer = maxf(0.0, _invincible_timer - delta)

	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		mods.trigger_hook("on_tick", {"owner": self})

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input * get_effective_move_speed()
		if _dash_cd <= 0.0 and Input.is_action_just_pressed("dash"):
			_start_dash(input)

	move_and_slide()

	_aim()
	if Input.is_action_pressed("attack") and _fire_cd <= 0.0:
		_fire()

	if Input.is_action_just_pressed("inject_rage"):
		RunManager.inject_factor("factor_rage")
	if Input.is_action_just_pressed("inject_fear"):
		RunManager.inject_factor("factor_fear")

## ---- 有效属性（含词条加成） ----
func get_effective_attack() -> float:
	return mods.get_stat(projectile_damage, "attack")

func get_effective_move_speed() -> float:
	return mods.get_stat(move_speed, "move_speed")

## ---- 词条 / 失控 ----
func on_attack_hit(_target: Node) -> void:
	mods.trigger_hook("on_hit", {"target": _target})

func _on_injected(payload: Dictionary) -> void:
	var list: Array = payload.get("modifiers", [])
	for mod_id in list:
		mods.apply(mod_id)
	# 注射成功短暂白闪。
	body_sprite.modulate = Color(1.5, 1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _base_color, 0.2)
	var factor_id := str(payload.get("factor_id", ""))
	var fname := "怒因子" if factor_id == "factor_rage" else "惧因子"
	EventBus.emit("fx.float_text", {"text": "注射 %s" % fname, "pos": global_position, "color": Color(0.6, 0.9, 1.0)})

func _on_unstable_state_changed(unstable: bool) -> void:
	if unstable:
		mods.apply("mod_instability_drain")
	else:
		mods.remove("mod_instability_drain")

## ---- 移动 / 射击 ----
func _aim() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir.length_squared() > 0.01:
		_aim_dir = dir
	_update_facing()

func _update_facing() -> void:
	if is_instance_valid(muzzle):
		muzzle.position = _aim_dir * 30.0
	if _front_tex == null:
		return
	if absf(_aim_dir.x) > absf(_aim_dir.y):
		body_sprite.texture = _front_tex
		body_sprite.flip_h = _aim_dir.x < 0.0
	else:
		body_sprite.flip_h = false
		body_sprite.texture = _back_tex if _aim_dir.y < 0.0 else _front_tex

func _start_dash(input: Vector2) -> void:
	_dash_dir = input.normalized() if input != Vector2.ZERO else _aim_dir
	_dash_timer = dash_time
	_dash_cd = dash_cooldown
	_invincible_timer = dash_time + 0.1
	EventBus.emit("player.dash", {})

func _fire() -> void:
	_fire_cd = fire_rate
	var dir := _aim_dir
	var p: Projectile = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(p)
	p.setup(global_position + dir * 28.0, dir, get_effective_attack(), projectile_speed, self)
	EventBus.emit("player.shoot", {})

## ---- 受击 / 死亡 ----
func take_damage(amount: float, _source: Node = null) -> void:
	if _invincible_timer > 0.0:
		return
	health.take_damage(amount)
	EventBus.emit("player.hp_changed", health.hp)
	_shake(6.0)

## 直接伤害（失控反噬等）：不触发无敌帧与震屏。
func take_raw_damage(amount: float) -> void:
	health.take_damage(amount)
	EventBus.emit("player.hp_changed", health.hp)

## 恢复生命（休息房等）。
func heal(amount: float) -> void:
	health.heal(amount)
	EventBus.emit("player.hp_changed", health.hp)

func _on_damaged(_amount: float, _new_hp: float) -> void:
	body_sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _base_color, 0.15)

func _on_health_died() -> void:
	EventBus.emit("player.died", {})
	set_physics_process(false)
	GameManager.back_to_lobby.call_deferred()

func _shake(amount: float) -> void:
	var tween := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(camera, "offset", off, 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _apply_art() -> void:
	_front_tex = Art.hero_front()
	_back_tex = Art.hero_back()
	if _front_tex != null:
		_base_color = Color.WHITE
		Art.fit_sprite(body_sprite, _front_tex, 52.0)
	else:
		_base_color = Color(0.35, 0.8, 0.95)
		body_sprite.texture = Placeholder.orb(20, Color.WHITE)
		body_sprite.scale = Vector2.ONE
	body_sprite.modulate = _base_color
	muzzle.texture = Placeholder.soft_glow(7, Color.WHITE)
	muzzle.modulate = Color.WHITE
