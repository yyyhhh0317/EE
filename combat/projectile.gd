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
	body_sprite.texture = Placeholder.circle(3, Color.WHITE)
	body_sprite.modulate = Color(0.9, 0.95, 1.0)

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
	CombatResolver.deal_damage(body, damage, source)
	queue_free()
