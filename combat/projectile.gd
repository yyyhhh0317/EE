class_name Projectile
extends Area2D
## 玩家因子能量投射物（v0.2.1 素材接入）：
## 优先使用 art/items/energy_{因子}.png（情绪色素材），缺失时回退程序辉光 + 情绪色 modulate。

@export var speed: float = 600.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var is_crit: bool = false
var color: Color = Color(0.85, 0.95, 1.0)
var factor_id: String = ""

@onready var body_sprite: Sprite2D = $Body

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## 视觉在 setup 时应用（add_child 之后 onready 才有效，且此时才知道因子）。
func _apply_visual() -> void:
	var tex: Texture2D = Art.energy(factor_id) if factor_id != "" else null
	if tex != null:
		Art.fit_sprite(body_sprite, tex, 30.0)
		body_sprite.modulate = Color.WHITE
		# 背后补一层情绪色辉光
		var glow := Sprite2D.new()
		glow.texture = Placeholder.soft_glow(14, Color.WHITE)
		glow.modulate = Color(color.r, color.g, color.b, 0.55)
		add_child(glow)
		move_child(glow, 0)
	else:
		body_sprite.texture = Placeholder.soft_glow(9, Color.WHITE)
		body_sprite.modulate = color
		var core := Sprite2D.new()
		core.texture = Placeholder.circle(3, Color.WHITE)
		core.modulate = Color(1, 1, 1)
		add_child(core)

func setup(pos: Vector2, dir: Vector2, dmg: float, spd: float, src: Node, crit: bool = false, col: Color = Color(0.85, 0.95, 1.0), scale_mult: float = 1.0, factor: String = "") -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	speed = spd
	source = src
	is_crit = crit
	color = col
	factor_id = factor
	rotation = direction.angle()
	if is_instance_valid(body_sprite):
		_apply_visual()
		if scale_mult != 1.0:
			body_sprite.scale = Vector2.ONE * scale_mult

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	var dealt := CombatResolver.deal_damage(body, damage, source, {"crit": is_crit})
	if dealt > 0.0 and source != null and source.has_method("on_attack_hit"):
		source.on_attack_hit(body)
	queue_free()
