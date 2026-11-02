extends RefCounted
class_name Crafter

# stations: Array ของ StringName ที่ "มีอยู่" ตอนนี้ เช่น [&"hand", &"workbench"]
# qty = จำนวนครั้งที่ craft (ไม่ใช่จำนวน output)
static func craft(db : ItemDatabase, inv : Inventory, recipe : CraftingRecipe, stations : Array, qty : int = 1) -> Dictionary:
	if db == null:
		return CraftResult.make(CraftResult.NULL_DB, qty, 0)
	if inv == null:
		return CraftResult.make(CraftResult.NULL_INVENTORY, qty, 0)
	if recipe == null:
		return CraftResult.make(CraftResult.UNKNOWN_RECIPE, qty, 0)
	if qty <= 0:
		return CraftResult.make(CraftResult.INVALID_QUANTITY, qty, 0)
	if recipe.inputs.is_empty() or recipe.outputs.is_empty():
		return CraftResult.make(CraftResult.BAD_RECIPE, qty, 0)
	var st : StringName = recipe.station_required if recipe.station_required != &"" else &"hand"
	if st != &"hand" and not stations.has(st):
		return CraftResult.make(CraftResult.WRONG_STATION, qty, 0)
	# รวมจำนวนต่อ item (กรณีสูตรมี input ซ้ำ id)
	var need : Dictionary = {}
	for i in recipe.inputs:
		if i == null or i.quantity <= 0 or db.get_item(i.item_id) == null:
			return CraftResult.make(CraftResult.BAD_RECIPE, qty, 0)
		need[i.item_id] = need.get(i.item_id, 0) + i.quantity * qty
	for id in need:
		if inv.count_of(id) < need[id]:
			return CraftResult.make(CraftResult.NOT_ENOUGH, qty, 0)
	for o in recipe.outputs:
		if o == null or o.quantity <= 0 or db.get_item(o.item_id) == null:
			return CraftResult.make(CraftResult.BAD_RECIPE, qty, 0)
	# dry-run บนสำเนา: หัก input แล้วใส่ output ถ้าล้ม = ไม่แตะของจริง
	var trial : Inventory = Inventory.from_dict(inv.to_dict(), db).get("inventory")
	if trial == null:
		return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	for id in need:
		if not trial.remove_item(db, id, need[id])["ok"]:
			return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	for o in recipe.outputs:
		if not trial.add_to_existing_stacks(db, o.item_id, o.quantity * qty)["ok"]:
			return CraftResult.make(CraftResult.OUTPUT_FULL, qty, 0)
	# ผ่านแล้วค่อยทำจริง
	for id in need:
		if not inv.remove_item(db, id, need[id])["ok"]:
			push_error("Crafter.craft: dry-run ผ่านแต่ remove ล้ม")
			return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	for o in recipe.outputs:
		if not inv.add_to_existing_stacks(db, o.item_id, o.quantity * qty)["ok"]:
			push_error("Crafter.craft: dry-run ผ่านแต่ add ล้ม")
			return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	return CraftResult.make(CraftResult.OK, qty, qty)
