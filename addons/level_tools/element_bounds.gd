@tool
extends RefCounted
## Where each kind of level element is, so it can be clicked in the 2D view (custom-drawn
## nodes give the editor no outline of their own). Mostly a box worked out from the element's
## own exported sizes, in its local coordinates; terrain, roofs and cover shapes are tested
## against their real outlines.

## Scripts in these folders are level elements.
const FOLDERS := ["res://cover/", "res://structures/", "res://interactive/", "res://hazards/",
	"res://environment/", "res://creatures/", "res://enemies/", "res://gameplay/"]
## Elements that follow the view and have no place of their own.
const SKIP := ["Bats", "Starlings", "MothSwarm"]
## Invisible areas: picked only where nothing visible is.
const AREAS := ["Fireflies", "Checkpoint", "LevelExit", "KillZone"]


static func class_of(node: Node) -> String:
	var sc := node.get_script() as Script
	return String(sc.get_global_name()) if sc else ""


static func is_element(node: Node) -> bool:
	var sc := node.get_script() as Script
	if sc == null or not node is Node2D:
		return false
	var path := sc.resource_path
	for f in FOLDERS:
		if path.begins_with(f):
			return not class_of(node) in SKIP
	return false


## The element's box in its own coordinates.
static func local_rect(n: Node2D) -> Rect2:
	var c := class_of(n)
	match c:
		"Terrain":
			return _bbox(n.get("_poly"))
		"Roof":
			return _bbox(n.get("_outer"))
		"RuinedWall":
			var s: Vector2 = n.size
			return Rect2(0, -s.y - n.gable, s.x, s.y + n.gable)
		"ShippingContainer":
			return Rect2(0, -n.size.y, n.size.x, n.size.y)
		"CrateStack":
			var h := 0
			for k in n.stacks:
				h = maxi(h, k)
			return Rect2(0, -h * n.crate_size, n.stacks.size() * n.crate_size, h * n.crate_size)
		"RockFace", "Boulder", "Bush":
			return Rect2(-n.size.x * 0.5, -n.size.y, n.size.x, n.size.y)
		"TreeStump":
			return Rect2(-n.width * 0.5, -n.height, n.width, n.height)
		"Boiler":
			return Rect2(-n.length * 0.5, -115, n.length, 115)
		"HayBales":
			var r: float = n.radius
			return Rect2(-n.bottom_row * r, -n.rows * r * 1.75 - 4, n.bottom_row * r * 2.0, n.rows * r * 1.75 + 4)
		"OldOak", "WindTree":
			var grown := _tree_bounds(n)
			if grown.has_area():
				return grown
			var s: float = n.size
			return Rect2(-200 * s, -330 * s, 400 * s, 330 * s) if c == "OldOak" else Rect2(-150 * s, -220 * s, 300 * s, 220 * s)
		"PineTree":
			var h: float = n.height
			return Rect2(-0.32 * h, -h - 12, 0.64 * h, h + 12)
		"FallingTree":
			return Rect2(-35, -n.height, 70, n.height)
		"WaterTower":
			return Rect2(-48, -n.height - 85, 96, n.height + 85)
		"HangingTarp":
			return Rect2(0, 0, n.width, n.drop)
		"Fireflies", "Chasm", "DeepWater", "MoltenPool", "SolidBlock", "SlidingGate", "MovingPlatform", "RebarSpikes", "Checkpoint", "LevelExit", "KillZone":
			return Rect2(Vector2.ZERO, n.size)
		"Girder":
			return Rect2(0, 0, n.length, n.depth)
		"Catwalk":
			return Rect2(0, -6, n.length, 16)
		"CarWreck":
			var s: float = n.size
			return Rect2(-70 * s, -52 * s, 140 * s, 54 * s)
		"WoodenFence":
			return Rect2(0, -n.height, n.length, n.height)
		"Cattails":
			return Rect2(0, -n.height, n.width, n.height)
		"GrassField":
			return Rect2(0, -30, n.width, 32)
		"PowerLine":
			var last := 0.0
			for x in n.pole_x:
				last = maxf(last, x)
			return Rect2(-32, -n.pole_height - 24, last + 64, n.pole_height + 24)
		"StreetLamp":
			return Rect2(-40, -24, 80, n.post_height + 24)
		"Lantern":
			return Rect2(-14, 0, 28, n.drop + 24)
		"ClothFlag":
			return Rect2(-6, -n.pole_height, 62, n.pole_height)
		"Windmill":
			return Rect2(-45, -175, 90, 175)
		"FireBarrel":
			return Rect2(-15, -42, 30, 42)
		"Puddle":
			return Rect2(-n.half_width, -5, n.half_width * 2.0, 10)
		"HangingChains":
			var r := Rect2(-6, 0, 12, 12)
			for d in n.drops:
				r = r.expand(Vector2(d.x + 6, d.y + 10))
			return r
		"RustyPipes":
			return _bbox(n.path).grow(8)
		"DropLoad":
			return Rect2(-n.size.x * 0.5, 0, n.size.x, n.chain_length + n.size.y)
		"SteamHammer":
			return Rect2(-40, -n.stroke - 130, 80, n.stroke + 130)
		"CollapsingBridge":
			return Rect2(0, -10, n.end.x, 50)
		"Lever":
			return Rect2(-14, -32, 28, 34)
		"PressurePlate":
			return Rect2(-n.width * 0.5, -8, n.width, 10)
		"PushCrate":
			return Rect2(-n.size.x * 0.5, -n.size.y, n.size.x, n.size.y)
		"SwingingBeam":
			var r := Rect2(-8, 0, 16, 16)
			for b in n.beams:
				r = r.merge(b)
			return r
		"TrapDoor":
			return Rect2(0, -6, n.width, 12)
		"Burrower":
			return Rect2(-n.patch_width * 0.5, -16, n.patch_width, 18)
		"Dangler":
			return Rect2(-16, 0, 32, n.rest_drop + 70)
		"Watcher":
			return Rect2(-22, -52, 44, 52)
		"Stalker":
			return Rect2(-16, -72, 32, 72)
		"Hound":
			return Rect2(-26, -36, 52, 36)
		"Crawler":
			return Rect2(-26, -20, 52, 22)
		"JumpingFish":
			return Rect2(0, -12, n.width, 20)
		"StrayCat":
			return Rect2(-18, -28, 36, 30)
		"Frog", "Rat", "PlasticBag":
			return Rect2(-11, -13, 22, 15)
		"Crow":
			return Rect2(-13, -17, 26, 19)
	return Rect2(-12, -12, 24, 24)


## How strongly the element claims a click at this world point: 0 when it is not there,
## otherwise a weight (the smallest wins). A hit on a real outline (a wall, a trunk, the
## ground) beats a hit on a box, and invisible areas come last.
static func hit_weight(n: Node2D, world: Vector2) -> float:
	var local := n.get_global_transform().affine_inverse() * world
	var c := class_of(n)
	var scale := absf(n.get_global_transform().determinant())
	if c == "Terrain" or c == "Roof":
		var poly: PackedVector2Array = n.get("_poly" if c == "Terrain" else "_outer")
		if poly.size() > 2 and Geometry2D.is_point_in_polygon(local, poly):
			return _area(local_rect(n)) * scale * 0.05
		return 0.0
	if c == "PowerLine":
		return 400.0 if _on_power_line(n, local) else 0.0
	if n.has_method("_cover_shapes"):
		for poly in n._cover_shapes():
			if Geometry2D.is_point_in_polygon(local, poly):
				return _area(local_rect(n)) * scale * 0.05
	var r := local_rect(n)
	if not r.has_point(local):
		return 0.0
	return _area(r) * scale * (1e6 if c in AREAS else 1.0)


## Near one of its poles or one of its sagging wires.
static func _on_power_line(n: Node2D, p: Vector2) -> bool:
	var top: float = -n.pole_height
	var xs: PackedFloat32Array = n.pole_x
	for x in xs:
		if absf(p.x - x) < 8.0 and p.y > top - 24.0 and p.y < 2.0:
			return true
	for i in xs.size() - 1:
		var a := xs[i]
		var b := xs[i + 1]
		if p.x < a or p.x > b:
			continue
		var u := (p.x - a) / maxf(b - a, 1.0)
		var sag := 4.0 * 26.0 * u * (1.0 - u)
		if p.y > top - 24.0 + sag * 0.6 - 10.0 and p.y < top + sag + 12.0:
			return true
	return false


static func _area(r: Rect2) -> float:
	return maxf(r.size.x * r.size.y, 1.0)


## The box round a tree's grown branches (and leaf clumps), from the tree's own data.
static func _tree_bounds(n: Node2D) -> Rect2:
	var pts := PackedVector2Array([Vector2.ZERO])
	var ends = n.get("_end")
	if ends is PackedVector2Array:
		pts.append_array(ends)
	var branches = n.get("_branches")
	if branches is Array:
		for b in branches:
			if not b is Dictionary:
				continue
			for k in ["start", "mid", "end"]:
				if b.get(k) is Vector2:
					pts.append(b[k])
			if b.get("clumps") is Array and b.get("end") is Vector2:
				for cl in b.clumps:
					pts.append((b.end as Vector2) + (cl.off as Vector2))
	if pts.size() < 3:
		return Rect2()
	var leaf := 22.0 * float(n.get("size") if n.get("size") != null else 1.0)
	return _bbox(pts).grow(leaf)


static func _bbox(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2(-12, -12, 24, 24)
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
