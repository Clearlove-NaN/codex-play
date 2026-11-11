class_name Battle
extends RefCounted

const COLS = 20
const ROWS = 10
const TROOPS = {
 "infantry": {"name":"步兵团", "cost":80, "steel":1, "hp":100, "attack":29, "move":3, "range":1},
 "tank": {"name":"装甲旅", "cost":150, "steel":3, "hp":140, "attack":43, "move":5, "range":1},
 "artillery": {"name":"炮兵营", "cost":120, "steel":2, "hp":85, "attack":38, "move":2, "range":3}
}
var cells: Array = []
var units: Array = []
var turn = 1
var phase = 1
var gold = [0, 300, 270]
var steel = [0, 9, 8]
var difficulty = 1
var scenario = 0
var result = 0
var next_id = 1
var kills = 0
var logbook: Array = []

func setup(level: int = 1, mission: int = 0) -> void:
 difficulty = level
 scenario = mission
 cells.clear()
 units.clear()
 turn = 1
 phase = 1
 result = 0
 next_id = 1
 kills = 0
 gold = [0, 360 if level == 0 else 300, 230 + level * 70]
 steel = [0, 11 if level == 0 else 9, 8 + level * 2]
 logbook = ["第 1 回合 · 北境攻势开始"]
 for r in ROWS:
  for q in COLS:
   var terrain = "plain"
   if q < 2 or (q < 4 and r > 6) or q > 18 or (q > 16 and r < 2):
    terrain = "water"
   elif (q * 7 + r * 13 + mission * 3) % 19 < 4:
    terrain = "forest"
   elif (q == 10 and r in [0, 1, 2, 6, 7, 9]) or (q == 13 and r in [1, 8]):
    terrain = "mountain"
   cells.append({"q":q, "r":r, "terrain":terrain, "owner":0, "city":"", "capital":false})
 _city(4, 3, "白石城", 1, true)
 _city(5, 7, "银港", 1)
 _city(7, 1, "松岭", 1)
 _city(9, 4, "河间", 0)
 _city(11, 8, "南桥", 0)
 _city(13, 5, "赤原", 2)
 _city(15, 2, "霜堡", 2)
 _city(16, 7, "黑石城", 2, true)
 for pos in [Vector2i(8, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 5)]:
  cell(pos).terrain = "plain"
 for spec in [[4,3,"infantry",1],[6,3,"tank",1],[6,5,"artillery",1],[5,6,"infantry",1],[7,1,"infantry",1], [16,7,"infantry",2],[14,5,"tank",2],[14,3,"artillery",2],[12,5,"infantry",2],[15,2,"infantry",2]]:
  spawn(Vector2i(spec[0],spec[1]),spec[2],spec[3])
 if mission == 1:
  spawn(Vector2i(12,8), "tank", 2)
  gold[1] += 100
 if level == 2:
  spawn(Vector2i(13,6), "tank", 2)

func _city(q: int, r: int, title: String, side: int, capital: bool = false) -> void:
 var c = cell(Vector2i(q,r))
 c.city = title
 c.owner = side
 c.capital = capital
 c.terrain = "plain"

func valid(p: Vector2i) -> bool:
 return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func cell(p: Vector2i) -> Dictionary:
 return cells[p.y * COLS + p.x] if valid(p) else {}

func pos(u: Dictionary) -> Vector2i:
 return Vector2i(int(u.q),int(u.r))

func unit_at(p: Vector2i) -> Dictionary:
 for u in units:
  if pos(u) == p: return u
 return {}

func unit_by_id(id: int) -> Dictionary:
 for u in units:
  if u.id == id: return u
 return {}

func axial(p: Vector2i) -> Vector2i:
 return Vector2i(p.x, p.y - (p.x - (p.x & 1)) / 2)

func distance(a: Vector2i, b: Vector2i) -> int:
 var d = axial(a) - axial(b)
 return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2

func neighbors(p: Vector2i) -> Array:
 var out: Array = []
 for q in range(p.x-1,p.x+2):
  for r in range(p.y-1,p.y+2):
   var v = Vector2i(q,r)
   if valid(v) and distance(p,v) == 1: out.append(v)
 return out

func spawn(p: Vector2i, kind: String, side: int, exhausted: bool = false) -> Dictionary:
 var u = {"id":next_id,"q":p.x,"r":p.y,"kind":kind,"side":side,"hp":TROOPS[kind].hp,"moves":0 if exhausted else TROOPS[kind].move,"acted":exhausted,"general":false,"repaired":false}
 next_id += 1
 units.append(u)
 return u

func move_cost(p: Vector2i, kind: String) -> int:
 var c = cell(p)
 if c.is_empty() or c.terrain == "water": return 999
 if c.terrain == "mountain": return 3 if kind == "infantry" else 999
 return 2 if c.terrain == "forest" else 1

func reachable(u: Dictionary) -> Dictionary:
 var costs = {pos(u):0}
 var frontier = [pos(u)]
 while not frontier.is_empty():
  var p: Vector2i = frontier.pop_front()
  for n in neighbors(p):
   if not unit_at(n).is_empty(): continue
   var cost: int = costs[p] + move_cost(n,u.kind)
   if cost <= int(u.moves) and (not costs.has(n) or cost < costs[n]):
    costs[n] = cost
    frontier.append(n)
 costs.erase(pos(u))
 return costs

func move_unit(u: Dictionary, p: Vector2i) -> bool:
 if result != 0 or int(u.side) != phase: return false
 var paths = reachable(u)
 if not paths.has(p): return false
 u.moves -= paths[p]
 u.q = p.x
 u.r = p.y
 var c = cell(p)
 if c.city != "" and int(c.owner) != int(u.side):
  c.owner = int(u.side)
  record("%s占领了%s" % ["我军" if u.side == 1 else "敌军",c.city])
  if c.capital: result = int(u.side)
 return true

func can_attack(a: Dictionary, b: Dictionary) -> bool:
 return not a.is_empty() and not b.is_empty() and result == 0 and int(a.side) == phase and a.side != b.side and not a.acted and distance(pos(a),pos(b)) <= int(TROOPS[a.kind].range)

func damage(a: Dictionary, b: Dictionary) -> int:
 var power: float = TROOPS[a.kind].attack
 if a.general: power += 12
 if a.kind == "tank" and b.kind == "infantry": power *= 1.2
 if a.kind == "artillery" and b.kind == "tank": power *= 1.25
 if b.kind == "tank": power *= 0.85
 var c = cell(pos(b))
 if c.terrain == "forest": power *= 0.8
 if c.terrain == "mountain" or c.city != "": power *= 0.75
 if b.general: power *= 0.85
 power *= 0.55 + 0.45 * float(a.hp) / TROOPS[a.kind].hp
 return maxi(6,roundi(power))

func attack(a: Dictionary, b: Dictionary) -> Dictionary:
 if not can_attack(a,b): return {}
 var dealt = damage(a,b)
 b.hp -= dealt
 a.acted = true
 a.moves = 0
 var counter = 0
 if b.hp <= 0:
  if a.side == 1: kills += 1
  units.erase(b)
 elif distance(pos(a),pos(b)) == 1 and b.kind != "artillery":
  counter = maxi(1,roundi(damage(b,a)*0.5))
  a.hp -= counter
  if a.hp <= 0: units.erase(a)
 record("%s%s：造成 %d 伤害%s" % ["我军" if a.side == 1 else "敌军", TROOPS[a.kind].name,dealt,"，反击 %d" % counter if counter else ""])
 return {"damage":dealt,"counter":counter}

func income(side: int) -> Vector2i:
 var n = 0
 for c in cells:
  if c.city != "" and int(c.owner) == side: n += 1
 return Vector2i(30+n*35,n)

func city_count(side: int) -> int:
 var n = 0
 for c in cells:
  if c.city != "" and int(c.owner) == side: n += 1
 return n

func recruit(p: Vector2i, kind: String) -> Dictionary:
 if result != 0 or not TROOPS.has(kind): return {}
 var c = cell(p)
 var d: Dictionary = TROOPS[kind]
 if c.is_empty() or c.city == "" or int(c.owner) != phase or gold[phase] < d.cost or steel[phase] < d.steel: return {}
 var places = [p] + neighbors(p)
 for place in places:
  if unit_at(place).is_empty() and move_cost(place,kind) < 999:
   gold[phase] -= d.cost
   steel[phase] -= d.steel
   record("%s组建了%s" % [c.city,d.name])
   return spawn(place,kind,phase,true)
 return {}

func repair(u: Dictionary) -> bool:
 if result != 0 or u.side != phase or u.repaired or u.hp >= TROOPS[u.kind].hp or gold[phase] < 50: return false
 var c = cell(pos(u))
 if c.city == "" or int(c.owner) != phase: return false
 gold[phase] -= 50
 u.hp = mini(int(TROOPS[u.kind].hp),int(u.hp)+35)
 u.repaired = true
 record("%s完成战地补给" % TROOPS[u.kind].name)
 return true

func appoint(u: Dictionary) -> bool:
 if result != 0 or u.side != phase or u.general or gold[phase] < 120: return false
 for other in units:
  if other.side == phase and other.general: return false
 gold[phase] -= 120
 u.general = true
 record("%s任命指挥官 · 林岚" % TROOPS[u.kind].name)
 return true

func begin_enemy() -> void:
 if result != 0 or phase != 1: return
 phase = 2
 _refresh(2)

func _refresh(side: int) -> void:
 var gain = income(side)
 gold[side] += gain.x
 steel[side] += gain.y
 for u in units:
  if int(u.side) == side:
   u.moves = TROOPS[u.kind].move
   u.acted = false
   u.repaired = false

func ai_step(id: int) -> Dictionary:
 var u = unit_by_id(id)
 if u.is_empty() or result != 0 or phase != 2: return {}
 var target: Dictionary = {}
 var best = -999.0
 for e in units:
  if can_attack(u,e):
   var score: float = damage(u,e) + (50 if e.hp <= damage(u,e) else 0)
   if score > best:
    target = e
    best = score
 if not target.is_empty():
  var origin = pos(u)
  var dest = pos(target)
  var hit = attack(u,target)
  return {"from":origin,"to":dest,"damage":hit.damage,"attack":true}
 var goals: Array = []
 for c in cells:
  if c.city != "" and int(c.owner) != 2: goals.append(Vector2i(c.q,c.r))
 for e in units:
  if e.side == 1: goals.append(pos(e))
 var paths = reachable(u)
 var destination = pos(u)
 best = -9999
 for p in paths:
  var nearest = 999
  for goal in goals: nearest = mini(nearest,distance(p,goal))
  var score: float = -nearest * 10 - paths[p] * 0.2
  var c = cell(p)
  if c.city != "" and int(c.owner) != 2: score += 70 if c.capital else 35
  for e in units:
   if e.side == 1 and distance(p,pos(e)) <= int(TROOPS[u.kind].range): score += 9
  if score > best:
   best = score
   destination = p
 var origin = pos(u)
 if destination != origin: move_unit(u,destination)
 target = {}
 best = -999
 for e in units:
  if can_attack(u,e) and damage(u,e) > best:
   best = damage(u,e)
   target = e
 if not target.is_empty():
  var dest = pos(target)
  var hit = attack(u,target)
  return {"from":destination,"to":dest,"damage":hit.damage,"attack":true}
 return {"from":origin,"to":destination,"attack":false}

func finish_enemy() -> void:
 if phase != 2: return
 if result == 0:
  for c in cells:
   if c.city != "" and int(c.owner) == 2:
    var kind = "infantry"
    if turn % 3 == 0: kind = "tank"
    elif turn % 3 == 1 and difficulty > 0: kind = "artillery"
    var count = 0
    for u in units:
     if u.side == 2: count += 1
    if count < 9 + difficulty * 2: recruit(Vector2i(c.q,c.r),kind)
  turn += 1
  if turn > 35:
   result = 2
   turn = 35
 phase = 1
 _refresh(1)
 record("第 %d 回合 · 我军行动" % turn)

func record(s: String) -> void:
 logbook.push_front(s)
 if logbook.size() > 40: logbook.resize(40)

func snapshot() -> Dictionary:
 return {"version":1,"cells":cells,"units":units,"turn":turn,"phase":phase,"gold":gold,"steel":steel,"difficulty":difficulty,"scenario":scenario,"result":result,"next_id":next_id,"kills":kills,"logbook":logbook}

func restore(data: Dictionary) -> bool:
 if data.get("version") != 1 or not data.get("cells") is Array or data.cells.size() != COLS*ROWS or not data.get("units") is Array: return false
 for u in data.units:
  if not u is Dictionary or not TROOPS.has(u.get("kind","")) or not valid(Vector2i(int(u.get("q",-1)),int(u.get("r",-1)))): return false
 cells = data.cells
 units = data.units
 turn = int(data.turn)
 phase = int(data.phase)
 gold = data.gold
 steel = data.steel
 difficulty = int(data.difficulty)
 scenario = int(data.scenario)
 result = int(data.result)
 next_id = int(data.next_id)
 kills = int(data.kills)
 logbook = data.logbook
 return true
