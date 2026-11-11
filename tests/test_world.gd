extends SceneTree
const Rules = preload("res://game/world_battle.gd")
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+label)

func _init() -> void:
 var b = Rules.new()
 b.setup()
 check(b.provinces.size() == 68,"real geography loaded")
 check(b.capitals.size() == 8,"eight capitals")
 for side in range(1,9):
  b.setup(side)
  check(b.player == side and b.phase == side,"each faction selectable")
  check(b.army_count(side) >= 3,"each faction starts with an army")
  check(b.unit_at(int(b.capitals[side])).kind == Rules.FACTIONS[side].elite,"faction-specific starting unit")
  check(b.distance(int(b.capitals[side]),int(b.capitals[8])) < 999,"connected world map")
 b.setup(1)
 for p in b.provinces:
  for n in p.neighbors:
   check(int(p.id) in b.province(int(n)).neighbors,"symmetric map adjacency")
 b.units.clear()
 # Technology modifies live unit statistics and preserves existing damage.
 var u = b.spawn(0,"infantry",1)
 b.gold[1] = 5000
 b.science[1] = 5000
 var before = b.unit_stats(u)
 var cost = b.research_cost("weapons")
 var old_gold = b.gold[1]
 var old_science = b.science[1]
 check(b.research("weapons"),"research weapons I")
 check(b.unit_stats(u).attack == before.attack+6,"weapons changes actual attack")
 check(b.gold[1] == old_gold-cost.x and b.science[1] == old_science-cost.y,"research consumes both currencies")
 u.hp -= 30
 before = b.unit_stats(u)
 var old_hp = u.hp
 check(b.research("armor"),"research armor")
 check(b.unit_stats(u).hp == before.hp+15 and u.hp == old_hp+15,"armor preserves damage while adding max HP")
 before = b.unit_stats(u)
 var remaining_move = u.moves
 check(b.research("logistics"),"research logistics")
 check(b.unit_stats(u).move == before.move+1 and u.moves == remaining_move+1,"logistics immediately improves remaining movement")
 var old_income = b.income(1)
 check(b.research("industry"),"research industry")
 check(b.income(1).x > old_income.x and b.income(1).z > old_income.z,"industry increases income and science")
 check(not b.recruit_reason(0,"commando").is_empty(),"special unit locked before weapons II")
 check(b.research("weapons"),"weapons II")
 check(b.recruit_reason(0,"tiger") == "其他势力的专属兵种","cannot recruit another faction elite")
 var elite = b.recruit(0,"commando")
 check(not elite.is_empty() and elite.kind == "commando","own elite unlocks and deploys")
 check(elite.acted and elite.moves == 0,"recruits wait a turn")
 check(b.recruit_reason(0,"fighter") == "需要航空工程 I","aircraft needs aviation")
 check(b.research("aviation"),"aviation unlock")
 b.units.clear()
 check(not b.recruit(0,"fighter").is_empty(),"aircraft recruits after tech")
 b.units.clear()
 check(not b.recruit(0,"destroyer").is_empty(),"British starting naval research unlocks ships")
 # Coastal restrictions and automatic transport on actual map edges.
 for edge in b.sea_edges:
  var a = int(edge[0]);var c = int(edge[1])
  check(b.province(a).coastal and b.province(c).coastal,"sea routes connect ports")
  check(b.move_cost(a,c,"tank",1) == 2 and b.move_cost(a,c,"commando",1) == 1,"commando transport bonus")
 var inland = -1
 for p in b.provinces:
  if not p.coastal: inland = int(p.id); break
 check(inland >= 0 and b.move_cost(0,inland,"destroyer",1) == 999,"ships cannot move inland")
 # Modifiers are scoped to the player, reversible, and survive serialization.
 b.setup(1)
 b.units.clear()
 check(b.set_cheat("resources",true),"enable resources modifier")
 check(b.gold[1] >= 99999 and b.science[1] >= 9999,"resource totals refill immediately")
 var ai_gold = b.gold[2]
 b.gold[1] = 0;b.steel[1] = 0
 check(not b.recruit(0,"infantry").is_empty(),"free recruit with empty resources")
 check(b.gold[1] == 0 and b.gold[2] == ai_gold,"free recruitment does not charge player or grant AI")
 check(b.research_cost("weapons") == Vector2i.ZERO,"modifier research UI shows zero cost")
 b.set_cheat("resources",false)
 check(b.recruit(0,"tank").is_empty(),"disabled modifier restores resource constraint")
 b.set_cheat("instant_research",true)
 b.science[1] = 0
 check(b.research("armor") and int(b.tech[1].armor) == 3,"instant research maxes selected branch without cost")
 check(not b.research("armor"),"max level research rejected")
 b.units.clear()
 var a_id = 0
 var z_id = int(b.province(a_id).neighbors[0])
 var a = b.spawn(a_id,"infantry",1)
 var e = b.spawn(z_id,"tank",2)
 b.phase = 2
 b.set_cheat("invincible",true)
 var hp = a.hp
 check(b.damage(e,a) == 0,"invincibility prevents incoming damage")
 var hit = b.attack(e,a)
 check(not hit.is_empty() and a.hp == hp,"combat applies invincibility")
 b.phase = 1
 b.set_cheat("unlimited_actions",true)
 a.acted = true;a.moves = 0
 check(b.can_attack(a,e),"infinite actions bypass prior attack")
 hit = b.attack(a,e)
 check(not hit.is_empty() and b.can_attack(a,e),"infinite actions allow repeated attack")
 b.set_cheat("invincible",false)
 check(b.damage(e,a) > 0,"turning invincibility off restores damage")
 b.units.clear()
 a = b.spawn(a_id,"infantry",1)
 a.moves = 0
 b.province(z_id).owner = 1
 check(b.move_unit(a,z_id),"infinite actions permit movement with spent points")
 b.set_cheat("unlimited_actions",false)
 check(b.reachable(a).is_empty(),"disabling action modifier restores spent movement")
 b.set_cheat("resources",true)
 var restored = Rules.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(b.snapshot()))),"JSON save round trip")
 check(restored.player == 1 and restored.cheats.resources and int(restored.tech[1].armor) == 3,"save retains tech and modifier state")
 check(restored.provinces.size() == 68 and restored.units.size() == 1,"save retains map and units")
 var bad = b.snapshot()
 bad.units.append(bad.units[0].duplicate(true))
 check(not restored.restore(bad),"reject overlapping/colliding save units")
 # Full multi-faction AI turns, including research, conquest and recruitment.
 b.setup(4,1)
 var started_units = b.units.size()
 var gained_territory = false
 for side in range(1,9):
  if side == b.player: continue
  var old_count = b.city_count(side)
  b.begin_enemy(side)
  check(b.phase == side,"AI phase matches nation")
  var ids = []
  for troop in b.units:
   if int(troop.side) == side: ids.append(int(troop.id))
  for id in ids: b.ai_step(id)
  b.finish_enemy(side)
  if b.city_count(side) > old_count: gained_territory = true
 check(gained_territory,"AI factions capture territory")
 var money = b.gold[4]
 b.begin_player()
 check(b.turn == 2 and b.phase == 4,"all factions resolve back to selected player")
 check(b.gold[4] > money,"player receives next-turn income")
 var occupied = {}
 for troop in b.units:
  check(not occupied.has(int(troop.province)),"no overlapping armies after AI")
  occupied[int(troop.province)] = true
  check(troop.hp > 0,"dead units removed")
 check(b.units.size() >= started_units,"AI can recruit reinforcements")
 # Capital loss eliminates a faction and its armies, rather than ending any battle.
 b.setup(1)
 b.units.clear()
 var enemy_cap = int(b.capitals[2])
 var neighbor = int(b.province(enemy_cap).neighbors[0])
 a = b.spawn(neighbor,"tank",1)
 a.moves = 10
 check(b.move_unit(a,enemy_cap),"occupy enemy capital")
 check(not b.is_alive(2) and b.result == 0,"one defeated opponent does not end eight-faction game")
 for p in b.provinces:
  if p.capital: p.owner = 1
 b._check_result()
 check(b.result == 1,"all eight capitals gives victory")
 b.setup(1)
 b.units.clear()
 b.phase = 2
 var own_cap = int(b.capitals[1])
 neighbor = int(b.province(own_cap).neighbors[0])
 e = b.spawn(neighbor,"tank",2)
 e.moves = 10
 check(b.move_unit(e,own_cap) and b.result == 2,"player capital loss gives defeat")
 b.setup(1)
 b.turn = 80
 b.begin_player()
 check(b.result == 2 and b.turn == 80,"turn limit")
 print("WORLD_RULES: %d checks, %d failures; eight factions, graph paths, technology, elites, cheats, economy, saves, AI, victory/defeat" % [checks,failures])
 quit(1 if failures > 0 else 0)
