class_name WorldBattle
extends RefCounted

# A deliberately fictional free-for-all on real geography. Province links are
# strategic routes, not tactical hexes. Sea links automatically transport land
# units, while ships are restricted to coastal provinces.
const FACTIONS = {
 1:{"name":"英国", "short":"英国", "color":"568bac", "elite":"commando", "bonus":"皇家海军：海军兵力 +25，海军科研起步"},
 2:{"name":"德国", "short":"德国", "color":"829197", "elite":"tiger", "bonus":"装甲先锋：装甲火力 +8，装甲科技起步"},
 3:{"name":"苏联", "short":"苏联", "color":"c65b51", "elite":"guards", "bonus":"钢铁洪流：陆军兵力 +15，火力科技起步"},
 4:{"name":"美国", "short":"美国", "color":"5b9c92", "elite":"sherman", "bonus":"工业动员：每回合额外 +50 军费、+2 工业"},
 5:{"name":"中国", "short":"中国", "color":"c5a455", "elite":"volunteer", "bonus":"纵深防御：步兵防御 +12%，补给科技起步"},
 6:{"name":"日本", "short":"日本", "color":"b67891", "elite":"zero", "bonus":"航空先驱：航空火力 +10，航空科技起步"},
 7:{"name":"法国", "short":"法国", "color":"7488bd", "elite":"legion", "bonus":"堡垒体系：本土防御 +10%，装甲科技起步"},
 8:{"name":"意大利", "short":"意大利", "color":"8caa6c", "elite":"bersaglieri", "bonus":"快速军团：步兵机动 +1，补给科技起步"}
}
const TROOPS = {
 "infantry":{"name":"步兵师","cost":110,"steel":1,"hp":110,"attack":31,"move":2,"range":1,"class":"infantry","description":"基础占领部队，山地作战不受机动惩罚"},
 "tank":{"name":"装甲师","cost":200,"steel":4,"hp":160,"attack":46,"move":3,"range":1,"class":"armor","description":"高速突击，攻击步兵时火力提高 20%"},
 "artillery":{"name":"重炮营","cost":170,"steel":3,"hp":95,"attack":40,"move":2,"range":2,"class":"artillery","description":"跨两地区炮击，远程攻击不受反击"},
 "fighter":{"name":"战斗机联队","cost":240,"steel":4,"hp":100,"attack":43,"move":4,"range":3,"class":"air","description":"需要航空 I；远程支援，忽略地形机动惩罚"},
 "destroyer":{"name":"驱逐舰队","cost":230,"steel":5,"hp":170,"attack":46,"move":3,"range":2,"class":"naval","description":"需要海军 I；仅部署、移动于沿海地区"},
 "commando":{"name":"皇家突击队","cost":180,"steel":2,"hp":135,"attack":42,"move":3,"range":1,"class":"infantry","faction":1,"description":"英国专属：跨海机动仅消耗 1 点"},
 "tiger":{"name":"虎式重装甲","cost":300,"steel":6,"hp":220,"attack":66,"move":2,"range":1,"class":"armor","faction":2,"description":"德国专属：厚重装甲，受到伤害降低 15%"},
 "guards":{"name":"近卫坦克军","cost":270,"steel":5,"hp":195,"attack":57,"move":3,"range":1,"class":"armor","faction":3,"description":"苏联专属：击毁敌军恢复 20 兵力"},
 "sherman":{"name":"谢尔曼突击群","cost":245,"steel":4,"hp":175,"attack":51,"move":4,"range":1,"class":"armor","faction":4,"description":"美国专属：均衡装甲，城市修复额外 +15"},
 "volunteer":{"name":"山地精锐师","cost":155,"steel":1,"hp":155,"attack":40,"move":3,"range":1,"class":"infantry","faction":5,"description":"中国专属：山地、森林作战火力提高 25%"},
 "zero":{"name":"零式航空队","cost":270,"steel":4,"hp":115,"attack":53,"move":5,"range":3,"class":"air","faction":6,"description":"日本专属：高速远程航空支援"},
 "legion":{"name":"外籍精锐军团","cost":190,"steel":2,"hp":165,"attack":45,"move":3,"range":1,"class":"infantry","faction":7,"description":"法国专属：坚守阵地，反击伤害提高"},
 "bersaglieri":{"name":"快速机动军","cost":175,"steel":2,"hp":135,"attack":43,"move":4,"range":1,"class":"infantry","faction":8,"description":"意大利专属：进攻后保留剩余机动"}
}
const TECH = {
 "weapons":{"name":"陆军火力","desc":"每级陆军火力 +6；II 级解锁本国专属兵种","max":3},
 "armor":{"name":"防护装甲","desc":"每级陆军兵力 +15，承受伤害降低 4%","max":3},
 "logistics":{"name":"战地补给","desc":"I / III 级机动 +1；每级城市修复 +10","max":3},
 "industry":{"name":"工业动员","desc":"每级地区军费 +18%，每回合科研 +2","max":3},
 "aviation":{"name":"航空工程","desc":"I 级解锁战机；每级航空火力 +8、兵力 +8","max":3},
 "naval":{"name":"海军工程","desc":"I 级解锁驱逐舰；每级舰艇火力 +8、兵力 +12","max":3}
}
const MAX_TURNS = 80
var provinces: Array = []
var units: Array = []
var player = 1
var phase = 1
var turn = 1
var result = 0
var gold: Array = []
var steel: Array = []
var science: Array = []
var tech: Dictionary = {}
var cheats = {"resources":false,"invincible":false,"unlimited_actions":false,"instant_research":false}
var logbook: Array = []
var next_id = 1
var difficulty = 1
var kills = 0
var capitals: Dictionary = {}
var alive: Dictionary = {}
var sea_edges: Array = []
var _province_index: Dictionary = {}
var _sea_lookup: Dictionary = {}
var _distance_cache: Dictionary = {}

func setup(player_faction: int = 1, level: int = 1) -> void:
 var f = FileAccess.open("res://assets/world/world.json", FileAccess.READ)
 if f == null:
  push_error("World map is missing")
  return
 var data = JSON.parse_string(f.get_as_text())
 if not data is Dictionary:
  push_error("Invalid world map")
  return
 setup_from_data(data,player_faction,level)

func setup_from_data(data: Dictionary, player_faction: int = 1, level: int = 1) -> void:
 provinces = data.get("provinces",[]).duplicate(true)
 sea_edges = data.get("sea_edges",[]).duplicate(true)
 player = clampi(player_faction,1,8)
 difficulty = clampi(level,0,2)
 phase = player
 turn = 1
 result = 0
 units = []
 next_id = 1
 kills = 0
 logbook = []
 capitals = {}
 alive = {}
 tech = {}
 gold = [0,0,0,0,0,0,0,0,0]
 steel = gold.duplicate()
 science = gold.duplicate()
 cheats = {"resources":false,"invincible":false,"unlimited_actions":false,"instant_research":false}
 _reindex()
 for p in provinces:
  p["original_owner"] = int(p.owner)
  if p.capital and int(p.owner) > 0: capitals[int(p.owner)] = int(p.id)
 for side in range(1,9):
  alive[side] = capitals.has(side)
  gold[side] = 600 if side == player else 380+difficulty*90
  steel[side] = 20
  science[side] = 115 if side == player else 70
  tech[side] = {}
  for key in TECH: tech[side][key] = 0
  match side:
   1: tech[side].naval = 1
   2: tech[side].armor = 1
   3: tech[side].weapons = 1
   4: tech[side].industry = 1
   5,8: tech[side].logistics = 1
   6: tech[side].aviation = 1
   7: tech[side].armor = 1
  if not alive[side]: continue
  spawn(int(capitals[side]),FACTIONS[side].elite,side)
  var count = 0
  for p in provinces:
   if int(p.owner) == side and int(p.id) != int(capitals[side]):
    spawn(int(p.id),["infantry","tank","artillery"][count%3],side)
    count += 1
    if count >= 3: break
 record("%s已进入世界征服 · 夺取全部 8 座首都" % FACTIONS[player].name)

func _reindex() -> void:
 _province_index.clear()
 _sea_lookup.clear()
 _distance_cache.clear()
 for p in provinces:
  p.id = int(p.id)
  p.owner = int(p.owner)
  var links: Array = []
  for n in p.neighbors: links.append(int(n))
  p.neighbors = links
  _province_index[int(p.id)] = p
 for edge in sea_edges:
  if edge is Array and edge.size() == 2:
   _sea_lookup["%d:%d" % [int(edge[0]),int(edge[1])]] = true
   _sea_lookup["%d:%d" % [int(edge[1]),int(edge[0])]] = true

func province(id: int) -> Dictionary:
 return _province_index.get(id,{})

func unit_at(id: int) -> Dictionary:
 for u in units:
  if int(u.province) == id: return u
 return {}

func unit_by_id(id: int) -> Dictionary:
 for u in units:
  if int(u.id) == id: return u
 return {}

func faction_name(side: int) -> String:
 return FACTIONS.get(side,{"name":"中立"}).name

func is_alive(side: int) -> bool:
 return bool(alive.get(side,false))

func city_count(side: int) -> int:
 var count = 0
 for p in provinces:
  if int(p.owner) == side: count += 1
 return count

func capital_count(side: int) -> int:
 var count = 0
 for p in provinces:
  if p.capital and int(p.owner) == side: count += 1
 return count

func army_count(side: int) -> int:
 var count = 0
 for u in units:
  if int(u.side) == side: count += 1
 return count

func spawn(where: int, kind: String, side: int, exhausted: bool = false) -> Dictionary:
 if province(where).is_empty() or not TROOPS.has(kind) or not unit_at(where).is_empty(): return {}
 var u = {"id":next_id,"province":where,"side":side,"kind":kind,"hp":1,"moves":0,"acted":exhausted,"repaired":false,"veteran":0}
 var stats = unit_stats(u)
 u.hp = stats.hp
 u.moves = 0 if exhausted else stats.move
 next_id += 1
 units.append(u)
 return u

func unit_stats(u: Dictionary) -> Dictionary:
 if u.is_empty() or not TROOPS.has(u.get("kind","")): return {}
 var d: Dictionary = TROOPS[u.kind].duplicate()
 var side = int(u.side)
 var t: Dictionary = tech.get(side,{})
 var category: String = d["class"]
 if category in ["infantry","armor","artillery"]:
  d.attack += int(t.get("weapons",0))*6
  d.hp += int(t.get("armor",0))*15
 if category == "air":
  d.attack += int(t.get("aviation",0))*8
  d.hp += int(t.get("aviation",0))*8
 if category == "naval":
  d.attack += int(t.get("naval",0))*8
  d.hp += int(t.get("naval",0))*12
 d.move += (int(t.get("logistics",0))+1)/2
 if side == 1 and category == "naval": d.hp += 25
 if side == 2 and category == "armor": d.attack += 8
 if side == 3 and category != "air" and category != "naval": d.hp += 15
 if side == 6 and category == "air": d.attack += 10
 if side == 8 and category == "infantry": d.move += 1
 d.attack += int(u.get("veteran",0))*4
 return d

func _is_sea(a: int, b: int) -> bool:
 return _sea_lookup.has("%d:%d" % [a,b])

func move_cost(a: int, b: int, kind: String, side: int = 1) -> int:
 var p = province(b)
 if p.is_empty() or not TROOPS.has(kind): return 999
 var category: String = TROOPS[kind]["class"]
 if category == "naval" and not p.coastal: return 999
 if category == "air": return 1
 if _is_sea(a,b): return 1 if kind == "commando" or category == "naval" else 2
 if p.terrain == "mountain" and category != "infantry": return 2
 if p.terrain == "forest" and category == "armor": return 2
 return 1

func reachable(u: Dictionary) -> Dictionary:
 if u.is_empty(): return {}
 var start = int(u.province)
 var budget = int(u.moves)
 if int(u.side) == player and cheats.unlimited_actions: budget = int(unit_stats(u).move)
 var costs = {start:0}
 var frontier = [start]
 while not frontier.is_empty():
  var p = int(frontier.pop_front())
  # A newly occupied enemy/neutral province must be captured before advancing.
  if p != start and int(province(p).owner) != int(u.side): continue
  for v in province(p).neighbors:
   var n = int(v)
   if not unit_at(n).is_empty(): continue
   var cost: int = int(costs[p])+move_cost(p,n,u.kind,int(u.side))
   if cost <= budget and (not costs.has(n) or cost < int(costs[n])):
    costs[n] = cost
    frontier.append(n)
 costs.erase(start)
 return costs

func distance(a: int, b: int) -> int:
 if a == b: return 0
 var key = "%d:%d" % [a,b]
 if _distance_cache.has(key): return int(_distance_cache[key])
 if province(a).is_empty() or province(b).is_empty(): return 999
 var d = {a:0}
 var queue = [a]
 while not queue.is_empty():
  var p = int(queue.pop_front())
  for v in province(p).neighbors:
   var n = int(v)
   if d.has(n): continue
   d[n] = int(d[p])+1
   if n == b:
    _distance_cache[key] = d[n]
    _distance_cache["%d:%d" % [b,a]] = d[n]
    return int(d[n])
   queue.append(n)
 return 999

func move_unit(u: Dictionary, destination: int) -> bool:
 if u.is_empty() or result != 0 or int(u.side) != phase: return false
 var paths = reachable(u)
 if not paths.has(destination): return false
 u.moves = maxi(0,int(u.moves)-int(paths[destination]))
 u.province = destination
 _capture(destination,int(u.side))
 return true

func _capture(where: int, side: int) -> void:
 var p = province(where)
 if int(p.owner) == side: return
 var previous = int(p.owner)
 p.owner = side
 record("%s占领%s" % [faction_name(side),p.name])
 if previous > 0 and alive.get(previous,false) and int(capitals.get(previous,-1)) == where:
  alive[previous] = false
  for other in provinces:
   if int(other.owner) == previous: other.owner = 0
  units = units.filter(func(u): return int(u.side) != previous)
  record("%s首都失守，部队解散，剩余领土转为中立" % faction_name(previous))
 _check_result()

func _check_result() -> void:
 if not alive.get(player,false): result = 2
 elif capital_count(player) >= capitals.size(): result = 1

func can_attack(a: Dictionary, b: Dictionary) -> bool:
 if a.is_empty() or b.is_empty() or result != 0: return false
 if int(a.side) != phase or int(a.side) == int(b.side): return false
 if a.acted and not (int(a.side) == player and cheats.unlimited_actions): return false
 return distance(int(a.province),int(b.province)) <= int(unit_stats(a).range)

func damage(a: Dictionary, b: Dictionary) -> int:
 var ad = unit_stats(a)
 var bd = unit_stats(b)
 if ad.is_empty() or bd.is_empty(): return 0
 var power = float(ad.attack)*(0.6+0.4*float(a.hp)/int(ad.hp))
 if ad["class"] == "armor" and bd["class"] == "infantry": power *= 1.2
 if ad["class"] == "artillery" and bd["class"] == "armor": power *= 1.2
 if bd["class"] == "armor": power *= 0.88
 var p = province(int(b.province))
 if ad["class"] != "air":
  if p.terrain == "forest": power *= 0.85
  elif p.terrain == "mountain": power *= 0.8
 if p.capital: power *= 0.85
 if b.kind == "tiger": power *= 0.85
 if int(b.side) == 5 and bd["class"] == "infantry": power *= 0.88
 if int(b.side) == 7 and int(p.get("original_owner",0)) == 7: power *= 0.9
 if b.kind != "fighter" and bd["class"] != "air" and bd["class"] != "naval": power *= 1.0-int(tech[int(b.side)].armor)*0.04
 if a.kind == "volunteer" and province(int(a.province)).terrain in ["mountain","forest"]: power *= 1.25
 if int(b.side) == player and cheats.invincible: return 0
 return maxi(5,roundi(power))

func attack(a: Dictionary, b: Dictionary) -> Dictionary:
 if not can_attack(a,b): return {}
 var dealt = damage(a,b)
 var origin = int(a.province)
 var target = int(b.province)
 b.hp -= dealt
 var unlimited = int(a.side) == player and cheats.unlimited_actions
 if not unlimited:
  a.acted = true
  if a.kind != "bersaglieri": a.moves = 0
 var counter = 0
 var destroyed = int(b.hp) <= 0
 if destroyed:
  if int(a.side) == player: kills += 1
  units.erase(b)
  a.veteran = mini(3,int(a.get("veteran",0))+1)
  if a.kind == "guards": a.hp = mini(int(unit_stats(a).hp),int(a.hp)+20)
 elif distance(origin,target) == 1 and TROOPS[b.kind]["class"] != "artillery":
  counter = roundi(damage(b,a)*(0.65 if b.kind == "legion" else 0.45))
  a.hp -= counter
  if int(a.hp) <= 0: units.erase(a)
 record("%s%s攻击%s：%d 伤害%s" % [faction_name(int(a.side)),TROOPS[a.kind].name,province(target).name,dealt," · 击溃" if destroyed else ""])
 return {"damage":dealt,"counter":counter,"destroyed":destroyed,"from":origin,"to":target}

func income(side: int) -> Vector3i:
 var n = city_count(side)
 var level = int(tech.get(side,{}).get("industry",0))
 return Vector3i(45+roundi(n*32*(1.0+level*0.18))+(50 if side == 4 else 0),maxi(1,n)+(2 if side == 4 else 0),12+n*5+level*2)

func research_cost(key: String, side: int = -1) -> Vector2i:
 if side < 0: side = player
 if not TECH.has(key): return Vector2i(99999,99999)
 var level = int(tech[side][key])
 if side == player and (cheats.resources or cheats.instant_research): return Vector2i.ZERO
 return Vector2i(95+level*70,55+level*45)

func research(key: String) -> bool:
 return _research(key,phase)

func _research(key: String, side: int) -> bool:
 if result != 0 or not TECH.has(key) or not alive.get(side,false) or int(tech[side][key]) >= int(TECH[key].max): return false
 var cost = research_cost(key,side)
 var free = side == player and (cheats.instant_research or cheats.resources)
 if not free and (gold[side] < cost.x or science[side] < cost.y): return false
 var old_hp = {}
 var old_move = {}
 for u in units:
  if int(u.side) == side:
   old_hp[int(u.id)] = unit_stats(u).hp
   old_move[int(u.id)] = unit_stats(u).move
 if not free:
  gold[side] -= cost.x
  science[side] -= cost.y
 tech[side][key] = int(TECH[key]["max"]) if side == player and cheats.instant_research else int(tech[side][key])+1
 for u in units:
  if int(u.side) == side:
   var hp_gain = int(unit_stats(u).hp)-int(old_hp[int(u.id)])
   u.hp += hp_gain
   u.moves += int(unit_stats(u).move)-int(old_move[int(u.id)])
 record("%s完成%s %s" % [faction_name(side),TECH[key].name,["0","I","II","III"][int(tech[side][key])]])
 return true

func recruit_reason(where: int, kind: String) -> String:
 if result != 0: return "战役已经结束"
 if not TROOPS.has(kind): return "未知兵种"
 var p = province(where)
 if p.is_empty() or int(p.owner) != phase: return "只能在本国地区招募"
 var d: Dictionary = TROOPS[kind]
 if d.has("faction") and int(d.faction) != phase: return "其他势力的专属兵种"
 if d.has("faction") and int(tech[phase].weapons) < 2: return "需要陆军火力 II"
 if d["class"] == "air" and int(tech[phase].aviation) < 1: return "需要航空工程 I"
 if d["class"] == "naval" and int(tech[phase].naval) < 1: return "需要海军工程 I"
 if d["class"] == "naval" and not p.coastal: return "舰艇需要沿海地区"
 if not (phase == player and cheats.resources) and (gold[phase] < d.cost or steel[phase] < d.steel): return "军费或工业不足"
 var spots = [where]+p.neighbors
 for id in spots:
  var q = province(int(id))
  if not q.is_empty() and int(q.owner) == phase and unit_at(int(id)).is_empty() and (d["class"] != "naval" or q.coastal): return ""
 return "本地和相邻本国地区均已驻军"

func recruit(where: int, kind: String) -> Dictionary:
 if recruit_reason(where,kind) != "": return {}
 var d: Dictionary = TROOPS[kind]
 var places = [where]+province(where).neighbors
 for id in places:
  var p = province(int(id))
  if int(p.owner) != phase or not unit_at(int(id)).is_empty() or (d["class"] == "naval" and not p.coastal): continue
  if not (phase == player and cheats.resources):
   gold[phase] -= d.cost
   steel[phase] -= d.steel
  var u = spawn(int(id),kind,phase,true)
  record("%s在%s组建%s" % [faction_name(phase),p.name,d.name])
  return u
 return {}

func repair(u: Dictionary) -> bool:
 if u.is_empty() or result != 0 or int(u.side) != phase or int(province(int(u.province)).owner) != phase or u.repaired: return false
 var stats = unit_stats(u)
 if int(u.hp) >= int(stats.hp): return false
 var free = phase == player and cheats.resources
 if gold[phase] < 65 and not free: return false
 if not free: gold[phase] -= 65
 u.hp = mini(int(stats.hp),int(u.hp)+35+int(tech[phase].logistics)*10+(15 if u.kind == "sherman" else 0))
 u.repaired = true
 record("%s在%s完成补给" % [stats.name,province(int(u.province)).name])
 return true

func upgrade(u: Dictionary) -> bool:
 if u.is_empty() or result != 0 or int(u.side) != phase or int(u.get("veteran",0)) >= 3: return false
 var free = phase == player and cheats.resources
 if not free and gold[phase] < 120: return false
 if not free: gold[phase] -= 120
 u.veteran = int(u.get("veteran",0))+1
 record("%s完成精锐训练，火力 +4" % unit_stats(u).name)
 return true

func set_cheat(key: String, enabled: bool) -> bool:
 if not cheats.has(key): return false
 cheats[key] = enabled
 if key == "resources" and enabled:
  gold[player] = maxi(int(gold[player]),99999)
  steel[player] = maxi(int(steel[player]),999)
  science[player] = maxi(int(science[player]),9999)
 record("修改器：%s%s" % [{"resources":"无限资源","invincible":"我军无敌","unlimited_actions":"无限行动","instant_research":"即时科技"}[key]," 已开启" if enabled else " 已关闭"])
 return true

func grant_resources() -> void:
 gold[player] += 5000
 steel[player] += 100
 science[player] += 1000
 record("修改器：补给 +5000 军费 / +100 工业 / +1000 科研")

func heal_all() -> void:
 for u in units:
  if int(u.side) == player: u.hp = unit_stats(u).hp
 record("修改器：我军全体恢复满额兵力")

func _refresh(side: int) -> void:
 var gain = income(side)
 gold[side] += gain.x
 steel[side] += gain.y
 science[side] += gain.z
 if side == player and cheats.resources:
  gold[player] = maxi(int(gold[player]),99999)
  steel[player] = maxi(int(steel[player]),999)
  science[player] = maxi(int(science[player]),9999)
 for u in units:
  if int(u.side) == side:
   u.moves = unit_stats(u).move
   u.acted = false
   u.repaired = false

func begin_enemy(side: int) -> void:
 if side == player or result != 0 or not alive.get(side,false): return
 phase = side
 _refresh(side)
 # AI research uses real resources and shares the same stat path as the player.
 var choices = ["weapons","armor","industry","logistics","aviation","naval"]
 for i in choices.size():
  var key: String = choices[(turn+side+i)%choices.size()]
  if _research(key,side): break

func ai_step(id: int) -> Dictionary:
 var u = unit_by_id(id)
 if u.is_empty() or result != 0 or phase == player or int(u.side) != phase: return {}
 var target: Dictionary = {}
 var best = -999.0
 for e in units:
  if can_attack(u,e):
   var value = float(damage(u,e))+(60 if int(e.hp) <= damage(u,e) else 0)
   if value > best:
    target = e
    best = value
 if not target.is_empty():
  var hit = attack(u,target)
  hit["attack"] = true
  return hit
 var origin = int(u.province)
 # One unit remains to defend a nation's original capital.
 if origin == int(capitals.get(phase,-1)) and army_count(phase) > 1: return {}
 var goals = []
 for p in provinces:
  if int(p.owner) != phase: goals.append(int(p.id))
 var destination = origin
 best = -99999
 for p in reachable(u):
  var nearest = 999
  for goal in goals: nearest = mini(nearest,distance(int(p),goal))
  var q = province(int(p))
  var score = -nearest*12.0
  if int(q.owner) != phase: score += 30
  if q.capital and int(q.owner) != phase: score += 55
  # Avoid marching into a firing line with critically damaged units.
  for enemy in units:
   if int(enemy.side) != phase and distance(int(p),int(enemy.province)) <= int(unit_stats(enemy).range): score -= 8 if int(u.hp) < 50 else 1
  score -= distance(origin,int(p))*0.1
  if score > best:
   best = score
   destination = int(p)
 if destination != origin: move_unit(u,destination)
 if result != 0: return {"from":origin,"to":destination,"attack":false}
 target = {}
 best = -999
 for e in units:
  if can_attack(u,e) and damage(u,e) > best:
   best = damage(u,e)
   target = e
 if not target.is_empty():
  var hit = attack(u,target)
  hit["attack"] = true
  return hit
 return {"from":origin,"to":destination,"attack":false}

func finish_enemy(side: int) -> void:
 if result != 0 or phase != side or not alive.get(side,false): return
 var limit = 7+difficulty*2
 for p in provinces:
  if int(p.owner) != side: continue
  var u = unit_at(int(p.id))
  if not u.is_empty() and int(u.side) == side and int(u.hp) < int(unit_stats(u).hp)*0.6: repair(u)
  if army_count(side) >= limit: continue
  var kind = "infantry"
  if turn%4 == 0: kind = FACTIONS[side].elite
  elif turn%3 == 0: kind = "tank"
  elif turn%3 == 1: kind = "artillery"
  if recruit(int(p.id),kind).is_empty(): recruit(int(p.id),"infantry")

func begin_player() -> void:
 phase = player
 if result != 0: return
 turn += 1
 if turn > MAX_TURNS:
  turn = MAX_TURNS
  result = 2
  record("80 回合期限已到，世界征服失败")
  return
 _refresh(player)
 record("第 %d 回合 · %s行动" % [turn,faction_name(player)])

func record(message: String) -> void:
 logbook.push_front(message)
 if logbook.size() > 50: logbook.resize(50)

func snapshot() -> Dictionary:
 return {"version":2,"provinces":provinces.duplicate(true),"sea_edges":sea_edges.duplicate(true),"units":units.duplicate(true),"player":player,"phase":phase,"turn":turn,"result":result,"gold":gold.duplicate(),"steel":steel.duplicate(),"science":science.duplicate(),"tech":tech.duplicate(true),"cheats":cheats.duplicate(),"logbook":logbook.duplicate(),"next_id":next_id,"difficulty":difficulty,"kills":kills,"capitals":capitals.duplicate(),"alive":alive.duplicate()}

func restore(data: Dictionary) -> bool:
 if int(data.get("version",0)) != 2: return false
 for key in ["provinces","units","gold","steel","science","sea_edges","logbook"]:
  if not data.get(key) is Array: return false
 if data.provinces.is_empty() or data.gold.size() != 9 or data.steel.size() != 9 or data.science.size() != 9: return false
 for key in ["tech","cheats","capitals","alive"]:
  if not data.get(key) is Dictionary: return false
 for key in ["player","phase","turn","result","next_id","difficulty","kills"]:
  if not data.has(key): return false
 if int(data.player) < 1 or int(data.player) > 8 or int(data.phase) < 1 or int(data.phase) > 8: return false
 var ids = {}
 for p in data.provinces:
  if not p is Dictionary or not p.has("id") or not p.has("owner") or not p.get("neighbors") is Array: return false
  if ids.has(int(p.id)) or int(p.owner) < 0 or int(p.owner) > 8: return false
  for key in ["name","lon","lat","capital","coastal","terrain"]:
   if not p.has(key): return false
  ids[int(p.id)] = true
 var occupied = {}
 var unit_ids = {}
 for u in data.units:
  if not u is Dictionary or not TROOPS.has(u.get("kind","")): return false
  for key in ["id","province","side","hp","moves","acted","repaired"]:
   if not u.has(key): return false
  if int(u.side) < 1 or int(u.side) > 8 or int(u.hp) <= 0 or not ids.has(int(u.province)) or occupied.has(int(u.province)) or unit_ids.has(int(u.id)): return false
  occupied[int(u.province)] = true
  unit_ids[int(u.id)] = true
 var restored_tech = {}
 var restored_capitals = {}
 var restored_alive = {}
 for side in range(1,9):
  var t = data.tech.get(str(side),data.tech.get(side))
  if not t is Dictionary: return false
  for key in TECH:
   if not t.has(key) or int(t[key]) < 0 or int(t[key]) > int(TECH[key].max): return false
  restored_tech[side] = t.duplicate(true)
  var cap = data.capitals.get(str(side),data.capitals.get(side,-1))
  if int(cap) >= 0:
   if not ids.has(int(cap)): return false
   restored_capitals[side] = int(cap)
  restored_alive[side] = bool(data.alive.get(str(side),data.alive.get(side,false)))
 for key in cheats:
  if not data.cheats.has(key): return false
 for p in data.provinces:
  for n in p.neighbors:
   if not ids.has(int(n)): return false
 provinces = data.provinces.duplicate(true)
 units = data.units.duplicate(true)
 sea_edges = data.sea_edges.duplicate(true)
 player = int(data.player)
 phase = int(data.phase)
 turn = int(data.turn)
 result = int(data.result)
 next_id = int(data.next_id)
 difficulty = int(data.difficulty)
 kills = int(data.kills)
 gold = data.gold.duplicate()
 steel = data.steel.duplicate()
 science = data.science.duplicate()
 tech = restored_tech
 capitals = restored_capitals
 alive = restored_alive
 cheats = data.cheats.duplicate()
 logbook = data.logbook.duplicate()
 _reindex()
 return true
