class_name Player
extends CharacterBody2D
## 玩家（零号受试者）· v0.2 重构：
## 俯视角走位 + 鼠标瞄准 + 因子能量发射 + 理智冲刺 + 临界状态（亢奋/暴走）+ 暴击 + 共鸣触发。

@export var move_speed: float = 220.0
@export var fire_rate: float = 0.15
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 600.0
@export var dash_speed: float = 620.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.5

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")
const EXCITED_MOVE_MULT := 1.15
const EXCITED_FIRE_MULT := 1.2
const BERSERK_DAMAGE_MULT := 1.5
const BERSERK_SIZE_MULT := 1.3
const CRIT_DAMAGE_MULT := 2.0

var _base_color := Color(0.35, 0.8, 0.95)  # 正常 tint（真实素材时为白）
var _front_tex: Texture2D
var _back_tex: Texture2D
var _aim_dir := Vector2.RIGHT
var _dash_fail_cd: float = 0.0
var _suppress_flash: bool = false  # 静默伤害（亢奋扣血/灼烧）不触发受击红闪

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

func _ready() -> void:
	add_to_group("player")
	mods = ModifierSystem.new()
	_apply_art()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_health_died)
	EventBus.on("build.changed", _on_build_changed)
	EventBus.on("run.state_changed", _on_run_state_changed)
	EventBus.on("run.sanity_depleted", _on_sanity_depleted)
	RunManager.set_player_ref(self)
	BuildManager.sync_mods(mods)

func _physics_process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_dash_fail_cd = maxf(0.0, _dash_fail_cd - delta)

	# 双轨资源 tick（理智回复 / 失控衰减 / 暴走吞噬由 RunManager 处理）
	RunManager.tick(delta, mods)
	# 亢奋状态持续扣血
	if RunManager.state == RunManager.State.EXCITED:
		take_raw_damage(RunManager.EXCITED_HP_DRAIN * delta)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input * get_effective_move_speed()
		if _dash_cd <= 0.0 and Input.is_action_just_pressed("dash"):
			_try_dash(input)

	move_and_slide()

	_aim()
	if Input.is_action_pressed("attack") and _fire_cd <= 0.0:
		_fire()

## ---- 有效属性（含词条 + 临界状态加成） ----
func get_effective_attack() -> float:
	return mods.get_stat(projectile_damage, "attack")

func get_effective_move_speed() -> float:
	var spd := mods.get_stat(move_speed, "move_speed")
	if RunManager.state == RunManager.State.EXCITED:
		spd *= EXCITED_MOVE_MULT
	return spd

func get_effective_fire_rate() -> float:
	var rate := fire_rate
	if RunManager.state == RunManager.State.EXCITED:
		rate /= EXCITED_FIRE_MULT
	return rate

func get_effective_crit_chance() -> float:
	return mods.get_stat(0.0, "crit_chance")

## ---- 构筑同步 ----
func _on_build_changed(_payload) -> void:
	BuildManager.sync_mods(mods)

## ---- 命中 / 共鸣 ----
func on_attack_hit(target: Node) -> void:
	mods.trigger_hook("on_hit", {"target": target, "owner": self})
	# 战栗共鸣：怒+惧相邻 → 命中概率恐惧
	var stacks := BuildManager.get_resonance_stacks("resonance_rage_fear")
	if stacks > 0 and target != null and is_instance_valid(target) and target.has_method("apply_fear"):
		var row := DataManager.get_resonance("resonance_rage_fear")
		var chance: float = float(row.get("params", {}).get("chance", 0.25)) * stacks
		if randf() < chance:
			target.apply_fear(float(row.get("params", {}).get("fear_time", 2.0)))
			BuildManager.record_event("fear_spread")
			EventBus.emit("fx.float_text", {"text": "战栗！", "pos": target.global_position, "color": UITheme.FEAR})

## 敌人死亡 → 触发击杀钩子（欢愉丰收等）。
func on_kill(target: Node) -> void:
	mods.trigger_hook("on_kill", {"target": target, "owner": self})

## ---- 临界状态 ----
func _state_color() -> Color:
	match RunManager.state:
		RunManager.State.BERSERK:
			return Color(1.4, 0.25, 0.3)
		RunManager.State.EXCITED:
			return Color(1.25, 0.75, 0.5)
		_:
			return _base_color

func _on_run_state_changed(payload: Dictionary) -> void:
	body_sprite.modulate = _state_color()

func _on_sanity_depleted(_payload) -> void:
	EventBus.emit("fx.float_text", {"text": "失控自毁！", "pos": global_position, "color": UITheme.RAGE})
	take_raw_damage(99999.0)

## ---- 移动 / 冲刺 / 射击 ----
func _try_dash(input: Vector2) -> void:
	if RunManager.state == RunManager.State.EXCITED or RunManager.state == RunManager.State.BERSERK:
		if _dash_fail_cd <= 0.0:
			_dash_fail_cd = 1.0
			EventBus.emit("fx.float_text", {"text": "临界区无法冲刺", "pos": global_position + Vector2(0, -40), "color": UITheme.RAGE})
		return
	if not RunManager.spend_sanity(RunManager.DASH_SANITY_COST):
		if _dash_fail_cd <= 0.0:
			_dash_fail_cd = 1.0
			EventBus.emit("fx.float_text", {"text": "理智不足", "pos": global_position + Vector2(0, -40), "color": Color(0.7, 0.75, 1.0)})
		return
	_dash_dir = input.normalized() if input != Vector2.ZERO else _aim_dir
	_dash_timer = dash_time
	_dash_cd = dash_cooldown
	_invincible_timer = dash_time + 0.1
	EventBus.emit("player.dash", {})

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

func _fire() -> void:
	_fire_cd = get_effective_fire_rate()
	var berserk := RunManager.state == RunManager.State.BERSERK
	var crit_chance := get_effective_crit_chance()
	var crit := crit_chance > 0.0 and randf() < crit_chance
	var dmg := get_effective_attack()
	if crit:
		dmg *= CRIT_DAMAGE_MULT
	if berserk:
		dmg *= BERSERK_DAMAGE_MULT
	var dir := _aim_dir
	var p: Projectile = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(p)
	var scale_mult := 1.0
	if crit:
		scale_mult *= 1.25
	if berserk:
		scale_mult *= BERSERK_SIZE_MULT
	var dom := _dominant()
	p.setup(global_position + dir * 28.0, dir, dmg, projectile_speed, self, crit, dom["color"], scale_mult, dom["factor_id"])
	RunManager.register_attack()
	if crit:
		EventBus.emit("player.crit", {"pos": global_position + dir * 40.0, "color": dom["color"]})
	EventBus.emit("player.shoot", {})

## 主导情绪：构筑中占比最高的情绪 → 返回 {factor_id, color}（投射物素材/暴击色）。
func _dominant() -> Dictionary:
	var counts := {}
	var fid_by_emotion := {}
	for i in BuildManager.SLOT_COUNT:
		var s := BuildManager.get_slot(i)
		var fid := str(s.get("factor_id", ""))
		if fid == "":
			continue
		var e := BuildManager.emotion_of_slot(i)
		counts[e] = int(counts.get(e, 0)) + 1
		if not fid_by_emotion.has(e):
			fid_by_emotion[e] = fid
	var best := ""
	for e in counts:
		if best == "" or int(counts[e]) > int(counts.get(best, 0)):
			best = e
	if best == "":
		return {"factor_id": "", "color": Color(0.85, 0.95, 1.0)}
	var fid: String = fid_by_emotion.get(best, "")
	var f := DataManager.get_factor(fid)
	var col := Color(0.85, 0.95, 1.0)
	if not f.is_empty():
		col = Color(str(f.get("color", "#d9f2ff")))
	return {"factor_id": fid, "color": col}

func _dominant_emotion_color() -> Color:
	return _dominant().get("color", Color(0.85, 0.95, 1.0))

## ---- 注射仪式（局部反馈；大字/白闪由 run.gd 负责） ----
func injection_fx(factor_id: String) -> void:
	body_sprite.modulate = Color(1.7, 1.7, 1.7)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _state_color(), 0.35)
	var f := DataManager.get_factor(factor_id)
	EventBus.emit("fx.float_text", {"text": "注射 %s" % str(f.get("name", "因子")), "pos": global_position, "color": Color(str(f.get("color", "#4dd8ff")))})

## ---- 受击 / 治疗 / 死亡 ----
func take_damage(amount: float, _source: Node = null) -> void:
	if _invincible_timer > 0.0:
		return
	health.take_damage(amount)
	RunManager.register_damaged()
	EventBus.emit("player.hp_changed", health.hp)
	_shake(6.0)

## 直接伤害（亢奋扣血/污染灼烧等）：不触发无敌帧、震屏与受击红闪。
func take_raw_damage(amount: float) -> void:
	_suppress_flash = true
	health.take_damage(amount)
	_suppress_flash = false
	EventBus.emit("player.hp_changed", health.hp)

## 恢复生命（休息房等）。
func heal(amount: float) -> void:
	health.heal(amount)
	EventBus.emit("player.hp_changed", health.hp)

## 设置无敌帧（情绪过载奖励）。
func set_invincible(time: float) -> void:
	_invincible_timer = maxf(_invincible_timer, time)

func _on_damaged(_amount: float, _new_hp: float) -> void:
	if _suppress_flash:
		return
	body_sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", _state_color(), 0.15)

func _on_health_died() -> void:
	EventBus.emit("player.died", {})
	set_physics_process(false)

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
