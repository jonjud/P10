extends RefCounted
class_name Salvager

# qty = จำนวนชิ้นที่ salvage (ไม่ใช่จำนวน output)
# rng: ฉีดเข้ามาเพื่อให้เทสต์ซ้ำได้ ถ้า null ใช้ตัวใหม่แบบสุ่ม
static func salvage(db : ItemDatabase, inv : Inventory, id : StringName, stations : Array, qty : int = 1, rng : RandomNumberGenerator = null) -> Dictionary:
	if db == null:
		return CraftResult.make(CraftResult.NULL_DB, qty, 0)
	if inv == null:
		return CraftResult.make(CraftResult.NULL_INVENTORY, qty, 0)
	var it : ItemData = db.get_item(id)
	if it == null:
		return CraftResult.make(CraftResult.UNKNOWN_RECIPE, qty, 0)
	if qty <= 0:
		return CraftResult.make(CraftResult.INVALID_QUANTITY, qty, 0)
	if not it.can_be_salvaged:
		return CraftResult.make(CraftResult.NOT_SALVAGEABLE, qty, 0)
	if it.salvage_yield.is_empty():
		return CraftResult.make(CraftResult.NO_SALVAGE_DATA, qty, 0)
	var st : StringName = it.salvage_station if it.salvage_station != &"" else &"any"
	if st != &"any" and st != &"hand" and not stations.has(st):
		return CraftResult.make(CraftResult.WRONG_STATION, qty, 0)
	if inv.count_of(id) < qty:
		return CraftResult.make(CraftResult.NOT_ENOUGH, qty, 0)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# คำนวณผลทั้งหมดก่อน (ยังไม่แตะ inventory)
	var gain : Dictionary = {}
	for n in qty:
		for e in it.salvage_yield:
			if e == null or db.get_item(e.item_id) == null:
				return CraftResult.make(CraftResult.BAD_RECIPE, qty, 0)
			if e.is_bonus and rng.randf() >= e.chance:
				continue
			var q : int = e.min_quantity if e.min_quantity == e.max_quantity else rng.randi_range(e.min_quantity, e.max_quantity)
			gain[e.item_id] = gain.get(e.item_id, 0) + q
	# dry-run บนสำเนา
	var trial : Inventory = Inventory.from_dict(inv.to_dict(), db).get("inventory")
	if trial == null:
		return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	if not trial.remove_item(db, id, qty)["ok"]:
		return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	for g in gain:
		if not trial.add_to_existing_stacks(db, g, gain[g])["ok"]:
			return CraftResult.make(CraftResult.OUTPUT_FULL, qty, 0)
	# ทำจริง
	if not inv.remove_item(db, id, qty)["ok"]:
		push_error("Salvager: dry-run ผ่านแต่ remove ล้ม")
		return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	for g in gain:
		if not inv.add_to_existing_stacks(db, g, gain[g])["ok"]:
			push_error("Salvager: dry-run ผ่านแต่ add ล้ม")
			return CraftResult.make(CraftResult.INTERNAL, qty, 0)
	return CraftResult.make(CraftResult.OK, qty, qty)
