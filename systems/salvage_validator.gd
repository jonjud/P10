extends RefCounted
class_name SalvageValidator

# คืนรายการ error (ว่าง = ผ่าน)
# กฎ core/lossy: DOC-04 §4.3-4.4 และ Brief
# กฎ bonus เล็ก (P10-15): ตัวเลขที่เสนอเอง ยังเป็น DIRECTION ปรับได้ใน P10-21
const BONUS_MAX_QTY : int = 1
const BONUS_MAX_ENTRIES : int = 1
# bonus value * 2 <= core value  (= bonus ไม่เกิน 50% ของ core)

static func validate(item_db : ItemDatabase, rdb : RecipeDatabase) -> Array:
	var errs : Array = []
	if item_db == null or rdb == null:
		return ["item_db หรือ rdb เป็น null"]
	for id in item_db._items:
		var it : ItemData = item_db._items[id]
		var core_count : int = 0
		var core_value : int = 0
		var bonus_count : int = 0
		var bonus_value : int = 0
		var max_value : int = 0   # core + bonus ที่ max (bonus นับ chance 1.0)
		for e in it.salvage_yield:
			if e == null:
				errs.append(String(id) + ": entry เป็น null")
				continue
			var ent : ItemData = item_db.get_item(e.item_id)
			if ent == null:
				errs.append(String(id) + ": salvage ไม่มี item " + String(e.item_id))
				continue
			if e.item_id == id:
				errs.append(String(id) + ": salvage คืนตัวเอง")
			if e.min_quantity < 1 or e.max_quantity < e.min_quantity:
				errs.append(String(id) + ": min/max ผิด " + String(e.item_id))
			if e.is_bonus:
				bonus_count += 1
				bonus_value += ent.value * e.max_quantity
				if e.chance <= 0.0 or e.chance > 1.0:
					errs.append(String(id) + ": bonus chance ต้องอยู่ใน (0,1]")
				if e.max_quantity > BONUS_MAX_QTY:
					errs.append(String(id) + ": bonus max_quantity ต้อง <= %d" % BONUS_MAX_QTY)
			else:
				core_count += 1
				core_value += ent.value * e.max_quantity
				if e.min_quantity != e.max_quantity or not is_equal_approx(e.chance, 1.0):
					errs.append(String(id) + ": core ต้อง min==max และ chance==1.0")
			max_value += ent.value * e.max_quantity
		if it.can_be_salvaged:
			var has_non_raw_core : bool = false
			for e in it.salvage_yield:
				if e != null and not e.is_bonus:
					var ent2 : ItemData = item_db.get_item(e.item_id)
					if ent2 != null and ent2.material_form != ItemData.MaterialForm.RAW:
						has_non_raw_core = true
			if not has_non_raw_core:
				errs.append(String(id) + ": core ทั้งหมดเป็น RAW ต้องคืนของระดับกลางอย่างน้อยหนึ่งอย่าง")
			if core_count < 1:
				errs.append(String(id) + ": can_be_salvaged แต่ไม่มี core entry")
			if bonus_count > BONUS_MAX_ENTRIES:
				errs.append(String(id) + ": bonus ได้ไม่เกิน %d entry" % BONUS_MAX_ENTRIES)
			if bonus_count > 0 and bonus_value * 2 > core_value:
				errs.append(String(id) + ": bonus value เกิน 50%% ของ core (%d vs %d)" % [bonus_value, core_value])
			var cost : int = _min_input_cost(item_db, rdb, id)
			if cost < 0:
				errs.append(String(id) + ": salvage ได้แต่ไม่มีสูตรผลิต หาต้นทุนไม่ได้")
			elif max_value >= cost:
				errs.append(String(id) + ": salvage %d >= ต้นทุน %d" % [max_value, cost])
		elif not it.salvage_yield.is_empty():
			errs.append(String(id) + ": มี salvage_yield แต่ can_be_salvaged = false")
	return errs

# ต้นทุน input ต่อ output 1 ชิ้น ของสูตรที่ถูกที่สุด (-1 = ไม่มีสูตร)
static func _min_input_cost(item_db : ItemDatabase, rdb : RecipeDatabase, id : StringName) -> int:
	var best : int = -1
	for rid in rdb.all_ids():
		var r : CraftingRecipe = rdb.get_recipe(rid)
		var produced : int = 0
		for o in r.outputs:
			if o.item_id == id:
				produced += o.quantity
		if produced <= 0:
			continue
		var cost : int = 0
		for i in r.inputs:
			cost += item_db.get_item(i.item_id).value * i.quantity
		cost = cost / produced
		if best < 0 or cost < best:
			best = cost
	return best
