class_name Player
extends CharacterBody2D
## 玩家（零号受试者）：俯视角走位 + 鼠标瞄准 + 因子能量发射 + 冲刺（无敌帧）。

@export var move_speed: float = 220.0
@export var fire_rate: float = 0.15
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 600.0
@export var dash_speed: float = 620.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.5

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")

var _base_color := Color(0.35, 0.8, 0.95)  # 青色

@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Body
@onready var muzzle: Sprite2D = $Muzzle
@onready var camera: Camera2D = $Camera2D

var _fire_cd: float = 0.0
var _dash_cd: float = 0.0
var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _invincible_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_apply_placeholder_textures()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_health_died)

func _physics_process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invincible_timer = maxf(0.0, _invincible_timer - delta)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input * move_speed
		if _dash_cd <= 0.0 and Input.is_action_just_pressed("dash"):
			_start_dash(input)

	move_and_slide()

	_aim()
	if Input.is_action_pressed("attack") and _fire_cd <= 0.0:
		_fire()

func _aim() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir.length_squared() > 0.01:
		rotation = dir.angle()

func _start_dash(input: Vector2) -> void:
	_dash_dir = input.normalized() if input != Vector2.ZERO else Vector2.RIGHT.rotated(rotation)
	_dash_timer = dash_time
	_dash_cd = dash_cooldown
	_invincible_timer = dash_time + 0.1
	EventBus.emit("player.dash", {})

func _fire() -> void:
	_fire_cd = fire_rate
	var dir := Vector2.RIGHT.rotated(rotation)
	var p: Projectile = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(p)
	p.setup(global_position + dir * 20.0, dir, projectile_damage, projectile_speed, self)
	EventBus.emit("player.shoot", {})

func take_damage(amount: float, _source: Node = null) -> void:
	if _invincible_timer > 0.0:
		return
	health.take_damage(amount)
	EventBus.emit("player.hp_changed", health.hp)
	_shake(6.0)

func _on_damaged(_amount: float, _new_hp: float) -> void:
	body_sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _base_color, 0.15)

func _on_health_died() -> void:
	EventBus.emit("player.died", {})
	set_physics_process(false)
	GameManager.back_to_menu.call_deferred()

func _shake(amount: float) -> void:
	var tween := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(camera, "offset", off, 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _apply_placeholder_textures() -> void:
	body_sprite.texture = Placeholder.circle(12, Color.WHITE)
	body_sprite.modulate = _base_color
	muzzle.texture = Placeholder.circle(4, Color.WHITE)
	muzzle.modulate = Color.WHITE
