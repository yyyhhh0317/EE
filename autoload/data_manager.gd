extends Node
## DataManager —— 加载 / 缓存 / 查询所有数据表。
##
## 数据放在 res://data/ 下，按「表名 = 子目录名」组织（factors / modifiers / skills / ...）。
## 每个 .json 文件可包含单个对象或对象数组，均要求带 `id` 字段。
## 详细表结构见 docs/03-数据表设计.md。

const DATA_ROOT := "res://data/"

## table_name -> (id -> row Dictionary)
var tables: Dictionary = {}

func _ready() -> void:
	reload_all()

## 重新扫描并加载 res://data/ 下的所有 JSON。
func reload_all() -> void:
	tables.clear()
	var root := DirAccess.open(DATA_ROOT)
	if root == null:
		push_warning("DataManager: 找不到数据目录 %s" % DATA_ROOT)
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if root.current_is_dir() and not entry.begins_with("."):
			_load_table(DATA_ROOT + entry, entry)
		entry = root.get_next()
	root.list_dir_end()
	print("[DataManager] 加载完成，共 %d 张表。" % tables.size())

## 读取一个表目录下所有 .json 文件。
func _load_table(dir_path: String, table_name: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var file := d.get_next()
	while file != "":
		if not d.current_is_dir() and file.ends_with(".json"):
			_load_file_into_table(dir_path + "/" + file, table_name)
		file = d.get_next()
	d.list_dir_end()

func _load_file_into_table(path: String, table_name: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("DataManager: 无法读取 %s" % path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_warning("DataManager: JSON 解析失败 %s" % path)
		return
	if not tables.has(table_name):
		tables[table_name] = {}
	if parsed is Array:
		for row in parsed:
			if row is Dictionary and row.has("id"):
				tables[table_name][row["id"]] = row
	elif parsed is Dictionary and parsed.has("id"):
		tables[table_name][parsed["id"]] = parsed

## 按表名 + ID 查询，返回 Dictionary（找不到返回空字典）。
func get_row(table: String, id: String) -> Dictionary:
	var t: Dictionary = tables.get(table, {})
	return t.get(id, {})

## 返回整张表（id -> row），表不存在返回空字典。
func get_rows(table: String) -> Dictionary:
	return tables.get(table, {})

## 便捷查询接口（后续随系统扩展）。
func get_factor(id: String) -> Dictionary: return get_row("factors", id)
func get_modifier(id: String) -> Dictionary: return get_row("modifiers", id)
func get_enemy(id: String) -> Dictionary: return get_row("enemies", id)
func get_skill(id: String) -> Dictionary: return get_row("skills", id)
func get_resonance(id: String) -> Dictionary: return get_row("resonances", id)
func get_pollution(id: String) -> Dictionary: return get_row("pollutions", id)
