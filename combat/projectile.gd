class_name Projectile
extends Area2D
## 玩家因子能量投射物。

@export var speed: float = 600.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var source: Node = null

@onready var body_sprite: Sprite2D = $Body

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_sprite.texture = Placeholder.soft_glow(9, Color.WHITE)
	body_sprite.modulate = Color(0.85, 0.95, 1.0)
	var core := Sprite2D.new()
	core.texture = Placeholder.circle(3, Color.WHITE)
	core.modulate = Color(1, 1, 1)
	add_child(core)

func setup(pos: Vector2, dir: Vector2, dmg: float, spd: float, src: Node) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	speed = spd
	source = src
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	var dealt := CombatResolver.deal_damage(body, damage, source)
	if dealt > 0.0 and source != null and source.has_method("on_attack_hit"):
		source.on_attack_hit(body)
	queue_free()
