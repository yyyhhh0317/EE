extends Node
## PoolManager —— 对象池（子弹 / 特效等高频实例复用）。

var _pools: Dictionary = {}      # type -> Array[Node]
var _factories: Dictionary = {}  # type -> Callable

## 注册某类型对象的工厂函数，用于池空时创建新实例。
func register_factory(type: String, factory: Callable) -> void:
	_factories[type] = factory
	if not _pools.has(type):
		_pools[type] = []

## 取出一个实例（池空则调用工厂新建）。
func acquire(type: String) -> Node:
	var pool: Array = _pools.get(type, [])
	if not pool.is_empty():
		return pool.pop_back()
	if _factories.has(type):
		var obj: Variant = _factories[type].call()
		if obj is Node:
			return obj
	push_warning("PoolManager: 未注册工厂且池为空: %s" % type)
	return null

## 归还实例到池中（调用方需自行把节点从场景树移除）。
func release(type: String, obj: Node) -> void:
	if not _pools.has(type):
		_pools[type] = []
	_pools[type].append(obj)

## 清空某类型池。
func clear(type: String) -> void:
	if _pools.has(type):
		for node in _pools[type]:
			if is_instance_valid(node):
				node.queue_free()
		_pools[type].clear()
