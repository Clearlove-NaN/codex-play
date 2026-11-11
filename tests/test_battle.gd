extends SceneTree

const Rules = preload("res://game/battle.gd")
var checks = 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  push_error("FAIL: "+label)
  quit(1)
  assert(value,label)

func _init() -> void:
 var b = Rules.new()
 b.setup()
 check(b.cells.size() == 200 and b.units.size() == 10,"campaign initial state")
 check(b.city_count(1) == 3 and b.city_count(2) == 3,"city ownership")
 check(b.income(1) == Vector2i(135,3),"city income")
 for q in range(1,19):
  for r in range(1,9):
   var p = Vector2i(q,r)
   check(b.neighbors(p).size() == 6,"six neighbors")
   for n in b.neighbors(p): check(b.distance(p,n) == 1 and p in b.neighbors(n),"symmetric adjacency")
 var tank = b.unit_by_id(2)
 var moves = b.reachable(tank)
 check(not moves.is_empty(),"tank has reachable tiles")
 check(not b.move_unit(tank,Vector2i(0,0)),"cannot move into sea")
 check(not b.move_unit(tank,Vector2i(16,7)),"cannot teleport to capital")
 check(not moves.has(Vector2i(4,3)),"cannot stack units")
 check(b.move_cost(Vector2i(10,1),"tank") == 999,"mountain blocks tanks")
 check(b.move_cost(Vector2i(10,1),"infantry") == 3,"infantry crosses mountain")
 var dest: Vector2i = moves.keys()[0]
 var cost: int = moves[dest]
 check(b.move_unit(tank,dest),"legal movement")
 check(tank.moves == 5-cost and b.pos(tank) == dest,"movement consumes path cost")
 # A controlled duel exercises actual health, retaliation, armor and firing range.
 b.units.clear()
 var a = b.spawn(Vector2i(8,4),"tank",1)
 var e = b.spawn(Vector2i(9,4),"infantry",2)
 check(b.can_attack(a,e),"adjacent enemy attack")
 var before: int = e.hp
 var hit = b.attack(a,e)
 check(e.hp == before-hit.damage and hit.counter > 0,"damage and retaliation")
 check(a.moves == 0 and a.acted and not b.can_attack(a,e),"one attack ends movement")
 var gun = b.spawn(Vector2i(6,4),"artillery",1)
 check(b.can_attack(gun,e),"artillery fires at three hexes")
 before = gun.hp
 hit = b.attack(gun,e)
 check(hit.counter == 0 and gun.hp == before,"ranged attacks avoid counterfire")
 var friendly = b.spawn(Vector2i(6,5),"infantry",1)
 check(not b.can_attack(friendly,a),"no friendly fire")
 # Recruiting uses both resources and deploys exhausted units.
 var money: int = b.gold[1]
 var metal: int = b.steel[1]
 var recruited = b.recruit(Vector2i(4,3),"tank")
 check(not recruited.is_empty(),"recruit at owned city")
 check(b.gold[1] == money-150 and b.steel[1] == metal-3,"recruit costs")
 check(recruited.moves == 0 and recruited.acted,"recruit waits until next turn")
 check(b.recruit(Vector2i(9,4),"infantry").is_empty(),"no recruitment at neutral city")
 b.gold[1] = 0
 check(b.recruit(Vector2i(4,3),"infantry").is_empty(),"insufficient resources")
 b.gold[1] = 500
 check(b.appoint(recruited),"appoint general")
 check(not b.appoint(friendly),"only one general")
 recruited.hp = 40
 check(b.repair(recruited) and recruited.hp == 75,"city repair")
 check(not b.repair(recruited),"repair once per turn")
 # Entering empty cities captures them; capitals finish the match.
 b.units.clear()
 var scout = b.spawn(Vector2i(8,4),"infantry",1)
 check(b.move_unit(scout,Vector2i(9,4)),"capture neutral city")
 check(b.city_count(1) == 4 and int(b.cell(Vector2i(9,4)).owner) == 1,"capture updates ownership")
 b.units.clear()
 scout = b.spawn(Vector2i(16,6),"tank",1)
 check(b.move_unit(scout,Vector2i(16,7)) and b.result == 1,"capital capture wins")
 check(not b.move_unit(scout,Vector2i(16,8)),"no movement after victory")
 # Serialization must survive JSON's int->float conversions.
 var loaded = Rules.new()
 var data: Dictionary = JSON.parse_string(JSON.stringify(b.snapshot()))
 check(loaded.restore(data),"JSON save round trip")
 check(loaded.result == 1 and loaded.city_count(1) == 5,"save preserves progress")
 check(not loaded.restore({"version":1,"cells":[]}),"reject invalid save")
 # Drive an entire AI turn and enforce occupancy and health invariants.
 for level in 3:
  b.setup(level)
  var initial_gold: int = b.gold[1]
  var initial_positions: Array = []
  for u in b.units:
   if u.side == 2: initial_positions.append(b.pos(u))
  b.begin_enemy()
  var ids: Array = []
  for u in b.units:
   if u.side == 2: ids.append(int(u.id))
  for id in ids: b.ai_step(id)
  var changed = false
  for u in b.units:
   if u.side == 2 and b.pos(u) not in initial_positions: changed = true
  check(changed,"AI advances toward objectives")
  b.finish_enemy()
  check(b.turn == 2 and b.phase == 1,"turn resolves to player")
  check(b.gold[1] == initial_gold+b.income(1).x,"turn grants income")
  var occupied = {}
  for u in b.units:
   check(not occupied.has(b.pos(u)),"no overlapping units")
   occupied[b.pos(u)] = true
   check(u.hp > 0 and b.cell(b.pos(u)).terrain != "water","valid deployed units")
 b.setup()
 b.turn = 35
 b.begin_enemy()
 b.finish_enemy()
 check(b.result == 2,"turn limit produces defeat")
 print("RULES_OK: %d assertions; movement, terrain, combat, economy, recruitment, generals, saves, AI, victory/defeat" % checks)
 quit(0)
