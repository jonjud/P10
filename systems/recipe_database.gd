extends RefCounted
class_name RecipeDatabase

var _recipes : Dictionary = {}
var errors : Array = []   # ข้อความ error ล่าสุด ไว้ให้เทสต์ตรวจ

# item_db ต้องโหลดแล้ว ใช้ตรวจว่า item id ในสูตรมีอยู่จริง
# stations: รายชื่อสถานีที่ถูกต้อง (hand + id ของ BuildingPieceData ที่เป็น STATION)
func load_from_directory(path : String, item_db : ItemDatabase) -> bool:
	errors = []
	if item_db == null:
		errors.append("item_db เป็น null")
		push_error("RecipeDatabase: item_db เป็น null")
		return false
	var dir : DirAccess = DirAccess.open(path)
	if not dir:
		errors.append("เปิด directory ไม่ได้: " + path)
		push_error(errors[-1])
		return false
	var loaded : Dictionary = {}
	dir.list_dir_begin()
	var file_name : String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var res = ResourceLoader.load(path.path_join(file_name))
			if res is CraftingRecipe:
				_validate_into(res, file_name, item_db, loaded)
			else:
				errors.append(file_name + ": ไม่ใช่ CraftingRecipe")
		file_name = dir.get_next()
	dir.list_dir_end()
	if not errors.is_empty():
		for e in errors:
			push_error("RecipeDatabase: " + e)
		return false
	_recipes = loaded
	return true

# ตรวจสูตรเดียว (เรียกจากเทสต์ได้โดยไม่ต้องมีไฟล์) คืนรายการ error ว่างถ้าผ่าน
static func validate_recipe(r : CraftingRecipe, item_db : ItemDatabase) -> Array:
	var errs : Array = []
	if r == null:
		return ["สูตรเป็น null"]
	if r.id == &"":
		errs.append("id ว่าง")
	if r.inputs.is_empty():
		errs.append(String(r.id) + ": ไม่มี inputs")
	if r.outputs.is_empty():
		errs.append(String(r.id) + ": ไม่มี outputs")
	for i in r.inputs:
		if i == null or i.quantity <= 0:
			errs.append(String(r.id) + ": input ผิดรูป")
		elif not item_db.has_item(i.item_id):
			errs.append(String(r.id) + ": input ไม่มี item " + String(i.item_id))
	for o in r.outputs:
		if o == null or o.quantity <= 0:
			errs.append(String(r.id) + ": output ผิดรูป")
		elif not item_db.has_item(o.item_id):
			errs.append(String(r.id) + ": output ไม่มี item " + String(o.item_id))
	
	var st : StringName = r.station_required if r.station_required != &"" else &"hand"
	if st != &"hand":
		var p : BuildingPieceData = item_db.get_item(st) as BuildingPieceData
		if p == null or p.category != BuildingPieceData.BuildingCategory.STATION:
			errs.append(String(r.id) + ": สถานีไม่มีอยู่จริง " + String(st))
	return errs

func _validate_into(r : CraftingRecipe, file_name : String, item_db : ItemDatabase, loaded : Dictionary) -> void:
	if loaded.has(r.id):
		errors.append(file_name + ": id ซ้ำ " + String(r.id))
		return
	for e in validate_recipe(r, item_db):
		errors.append(file_name + ": " + e)
	loaded[r.id] = r

func get_recipe(id : StringName) -> CraftingRecipe:
	return _recipes.get(id)

func has_recipe(id : StringName) -> bool:
	return _recipes.has(id)

func all_ids() -> Array:
	var ids : Array = _recipes.keys()
	ids.sort()
	return ids
