extends RefCounted
class_name LevelCatalog
## Metadados dos níveis exibidos no menu e usados para recordes.

const LEVELS := [
	{
		"id": 1,
		"name": "level_1_name",
		"tagline": "level_1_tagline",
		"accent": Color("35c3a6"),
		"difficulty": 1,
		"checkpoints": 5,
		"fish": 26,
		"sections": 7,
	},
	{
		"id": 2,
		"name": "level_2_name",
		"tagline": "level_2_tagline",
		"accent": Color("55c8ff"),
		"difficulty": 2,
		"checkpoints": 5,
		"fish": 18,
		"sections": 7,
	},
	{
		"id": 3,
		"name": "level_3_name",
		"tagline": "level_3_tagline",
		"accent": Color("b07cff"),
		"difficulty": 3,
		"checkpoints": 5,
		"fish": 20,
		"sections": 7,
	},
	{
		"id": 4,
		"name": "level_4_name",
		"tagline": "level_4_tagline",
		"accent": Color("ff6fa8"),
		"difficulty": 4,
		"checkpoints": 5,
		"fish": 16,
		"sections": 7,
	},
]


static func count() -> int:
	return LEVELS.size()


static func get_level(level_id: int) -> Dictionary:
	for entry in LEVELS:
		if int(entry["id"]) == level_id:
			return entry
	return LEVELS[0]


static func ids() -> Array[int]:
	var out: Array[int] = []
	for entry in LEVELS:
		out.append(int(entry["id"]))
	return out
