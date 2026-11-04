extends RefCounted
class_name StationFinder

const REACH : float = 64.0   # ชั่วคราว ปรับใน P10-21

# คืนรายชื่อสถานีที่ใช้ได้ ณ ตำแหน่ง origin (hand มีเสมอ)
static func available(db : ItemDatabase, grid : BuildGrid, origin : Vector2, reach : float = REACH) -> Array:
	var out : Array = [&"hand"]
	if db == null or grid == null:
		return out
	for s in grid.all_structs():
		var p : BuildingPieceData = db.get_item(StringName(s["piece"])) as BuildingPieceData
		if p == null or p.category != BuildingPieceData.BuildingCategory.STATION:
			continue
		var size : Vector2 = Vector2(BuildGrid.footprint(p, s["rot"]) * BuildConst.CELL_SIZE)
		var rect : Rect2 = Rect2(BuildConst.cell_to_world(s["cell"]), size)
		var nearest : Vector2 = Vector2(clampf(origin.x, rect.position.x, rect.end.x), clampf(origin.y, rect.position.y, rect.end.y))
		if origin.distance_to(nearest) <= reach and not out.has(p.id):
			out.append(p.id)
	return out
