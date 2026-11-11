extends Control

const Rules = preload("res://game/battle.gd")
const CN = preload("res://assets/fonts/Chinese.ttc")
const EN = preload("res://assets/fonts/Interface.ttf")
const SERIF = preload("res://assets/fonts/Title.ttf")
const BG = Color("101d23")
const PANEL = Color("192a2f")
const LINE = Color("35464a")
const GOLD = Color("d9bc7d")
const INK = Color("e9eadf")
const MUTED = Color("94a7a7")
const BLUE = Color("8dc8c3")
const RED = Color("e18d7d")
const ORIGIN = Vector2(66,220)
const R = 33.0
const SAVE_PATH = "user://campaign.json"
var battle = Rules.new()
var screen = "menu"
var selected = Vector2i(-1,-1)
var selected_id = -1
var buttons: Array = []
var difficulty = 1
var mission = 0
var modal = ""
var busy = false
var toast = ""
var toast_time = 0.0
var total_time = 0.0
var effects: Array = []
var hovered = Vector2i(-1,-1)
var show_grid = true
var sound_on = true
var audio: AudioStreamPlayer
var saved_available = false
var last_touch = -10.0
var art_transform = Transform2D.IDENTITY
var territory_cache = {}
var territory_key = ""

func _ready() -> void:
 battle.setup()
 saved_available = FileAccess.file_exists(SAVE_PATH)
 audio = AudioStreamPlayer.new()
 add_child(audio)
 if "--battle" in OS.get_cmdline_user_args():
  screen = "battle"
  selected = Vector2i(6,3)
  selected_id = 2
 if "--capture" in OS.get_cmdline_user_args():
  await get_tree().create_timer(1.2).timeout
  get_viewport().get_texture().get_image().save_png("/workspace/artifacts/iron-meridian-"+screen+".png")
  get_tree().quit()
 if "--ui-test" in OS.get_cmdline_user_args():
  await _ui_test()

func _process(delta: float) -> void:
 total_time += delta
 if toast_time > 0: toast_time -= delta
 for fx in effects: fx.life -= delta
 effects = effects.filter(func(fx): return fx.life > 0)
 queue_redraw()

func box(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 8, width: int = 1) -> void:
 var style = StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = border
 style.set_border_width_all(width)
 style.set_corner_radius_all(radius)
 draw_style_box(style,rect)

func txt(s: String, at: Vector2, size: int = 20, color: Color = INK, font: Font = CN) -> void:
 draw_string(font,at,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(s: String, rect: Rect2, size: int = 20, color: Color = INK, font: Font = CN) -> void:
 var dim = font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
 txt(s,Vector2(rect.position.x+(rect.size.x-dim.x)*0.5,rect.position.y+rect.size.y*0.5+size*0.36),size,color,font)

func button(id: String, title: String, rect: Rect2, primary: bool = false, enabled: bool = true, size: int = 20) -> void:
 var over = rect.has_point(get_local_mouse_position()) and enabled
 var fill = GOLD if primary else Color("23393e")
 if over: fill = fill.lightened(0.08)
 if not enabled: fill = Color("203034")
 box(rect,fill, GOLD if primary else LINE,6)
 center(title,rect,size,BG if primary else (INK if enabled else MUTED.darkened(0.35)))
 buttons.append({"id":id,"rect":rect,"enabled":enabled})

func _draw() -> void:
 buttons.clear()
 draw_rect(Rect2(0,0,size.x,size.y),BG)
 for i in range(0,1600,40): draw_line(Vector2(i,0),Vector2(i,900),Color(0.7,0.8,0.8,0.018))
 for j in range(0,900,40): draw_line(Vector2(0,j),Vector2(1600,j),Color(0.7,0.8,0.8,0.018))
 if screen == "menu": _draw_menu()
 else: _draw_battle()
 if toast_time > 0 and modal == "":
  var w = maxf(400,CN.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+54)
  box(Rect2(800-w/2,760,w,46),Color("10252d"),GOLD,8)
  center(toast,Rect2(800-w/2,760,w,46),20)
 if modal != "": _draw_modal()

func _draw_menu() -> void:
 # The battlefield remains a real, generated map behind the cover.
 art_transform = Transform2D(0,Vector2(1.18,1.18),0,Vector2(320,-80))
 draw_set_transform_matrix(art_transform)
 _map(false)
 art_transform = Transform2D.IDENTITY
 draw_set_transform(Vector2.ZERO)
 draw_rect(Rect2(0,0,1600,900),Color(0.025,0.055,0.065,0.64))
 draw_rect(Rect2(0,0,820,900),Color(0.035,0.065,0.077,0.9))
 for i in 60:
  draw_line(Vector2(820+i*7,0),Vector2(820+i*7,900),Color(0.035,0.065,0.077,(1-float(i)/60)*0.8),7)
 _emblem(Vector2(82,74),26,GOLD)
 txt("MERIDIAN  /  STRATEGY DIVISION",Vector2(124,82),17,GOLD,EN)
 txt("铁幕前线",Vector2(78,265),88,INK)
 txt("IRON MERIDIAN",Vector2(84,316),31,GOLD,SERIF)
 draw_line(Vector2(86,352),Vector2(152,352),GOLD,3)
 txt("每一道边界，都由你的决策改写。",Vector2(86,402),25,INK)
 txt("集结军团，争夺城市，在北境的硝烟中掌握主动。",Vector2(86,445),20,MUTED)
 txt("离线单机   /   回合制战术   /   原创架空战役",Vector2(86,482),17,MUTED)
 box(Rect2(86,526,604,116),Color("182b2f"),LINE,8)
 txt("战役选择",Vector2(106,557),15,GOLD)
 txt("01  北境破晓" if mission == 0 else "02  钢铁洪流",Vector2(106,591),25)
 txt("均衡推进 · 首次游玩推荐" if mission == 0 else "敌方增援 · 更多初始补给",Vector2(106,620),16,MUTED)
 button("mission","切换  →",Rect2(548,558,120,52),false,true,18)
 txt("作战难度",Vector2(86,683),17,MUTED)
 for i in 3:
  button("difficulty"+str(i),["新兵","指挥官","老兵"][i],Rect2(194+i*166,653,154,46),difficulty == i,true,18)
 button("new","开始征服     →",Rect2(86,726,350,66),true,true,25)
 button("continue","继续战役",Rect2(454,726,236,66),false,saved_available,22)
 button("help","作战手册",Rect2(86,814,156,42),false,true,17)
 txt("ANDROID  /  v0.1  可玩原型",Vector2(270,843),15,MUTED, CN)
 # Campaign dossier.
 box(Rect2(1116,584,382,192),Color(0.075,0.13,0.15,0.92),Color("556465"),4)
 txt("作 战 档 案   /   001",Vector2(1142,624),17,GOLD)
 txt("北境战区",Vector2(1142,670),32)
 txt("蓝方联军  vs  赤岩军团",Vector2(1142,706),18,MUTED)
 txt("目标：35 回合内夺取黑石城",Vector2(1142,744),19,INK)
 _compass(Vector2(1454,136),GOLD)
 txt("N O R T H E R N   F R O N T",Vector2(1050,848),16,Color("728581"),EN)

func _draw_battle() -> void:
 box(Rect2(24,22,1552,103),PANEL,LINE,8)
 _emblem(Vector2(62,70),24,GOLD)
 txt("铁幕前线",Vector2(104,67),29)
 txt("IRON MERIDIAN",Vector2(106,96),12,GOLD,EN)
 draw_line(Vector2(325,44),Vector2(325,102),LINE)
 txt("北境破晓" if battle.scenario == 0 else "钢铁洪流",Vector2(350,65),23)
 txt("第 %02d / 35 回合" % battle.turn,Vector2(350,96),18,MUTED)
 _resource(Vector2(600,46),"军费",str(battle.gold[1]),"+%d / 回合" % battle.income(1).x,GOLD)
 _resource(Vector2(822,46),"工业",str(battle.steel[1]),"+%d / 回合" % battle.income(1).y,BLUE)
 _resource(Vector2(1023,46),"城市",str(battle.city_count(1))+" / 8","控制区",INK)
 button("sound","音效 开" if sound_on else "音效 关",Rect2(1230,48,112,48),false,true,16)
 button("pause","暂停  ≡",Rect2(1360,48,188,48),false,not busy,20)
 box(Rect2(24,145,1120,657),Color("20383f"),LINE,8)
 _map(true)
 box(Rect2(1164,145,412,657),PANEL,LINE,8)
 _sidebar()
 box(Rect2(24,821,1120,57),PANEL,LINE,8)
 draw_circle(Vector2(49,850),5,RED if busy else BLUE)
 txt("敌军行动中…" if busy else "我军行动",Vector2(65,857),18,RED if busy else BLUE)
 txt("点选部队 → 蓝格移动 / 红圈攻击   ·   点城市招募",Vector2(207,857),18,MUTED)
 button("help","?  手册",Rect2(976,831,150,37),false,true,17)
 button("end","敌军行动中…" if busy else "结束回合    →",Rect2(1164,821,412,57),true,not busy and battle.result == 0,23)
 for fx in effects:
  var p: Vector2 = fx.to
  if fx.has("from"): draw_line(fx.from,p,Color(GOLD,fx.life),3,true)
  draw_arc(p,(1.1-fx.life)*48+8,0,TAU,36,Color(RED,clampf(fx.life,0,1)),3,true)
  if fx.has("text"): center(fx.text,Rect2(p.x-65,p.y-60-(1-fx.life)*28,130,36),26,RED)

func _resource(p: Vector2, title: String, value: String, hint: String, color: Color) -> void:
 draw_circle(p+Vector2(10,20),8,color)
 txt(title,p+Vector2(28,5),15,MUTED)
 txt(value,p+Vector2(28,37),28,color,EN)
 txt(hint,p+Vector2(100,35),13,MUTED)

func hex_pos(p: Vector2i) -> Vector2:
 return ORIGIN + Vector2(p.x*R*1.5,(p.y+0.5*(p.x&1))*R*sqrt(3))

func hex_points(p: Vector2, radius: float = R-1) -> PackedVector2Array:
 var points = PackedVector2Array()
 for i in 6: points.append(p+Vector2(cos(i*PI/3),sin(i*PI/3))*radius)
 return points

func outline(points: PackedVector2Array, color: Color, width: float = 1) -> void:
 var closed = points.duplicate()
 closed.append(points[0])
 draw_polyline(closed,color,width,true)

func _map(interactive: bool) -> void:
 # Water, topographic land and terrain symbols use original vector artwork.
 var key = ""
 for c in battle.cells:
  if c.city != "": key += str(c.owner)
 if key != territory_key:
  territory_key = key
  territory_cache.clear()
 var u = battle.unit_by_id(selected_id)
 var paths = battle.reachable(u) if interactive and not u.is_empty() and u.side == 1 and not busy else {}
 for c in battle.cells:
  var coord = Vector2i(c.q,c.r)
  var p = hex_pos(coord)
  var points = hex_points(p)
  var shade = float((int(c.q)*7+int(c.r)*11)%7)/140.0
  if c.terrain == "water":
   draw_colored_polygon(points,Color("23434e").lightened(shade*0.65))
   for i in 2:
    draw_line(p+Vector2(-11+i*5,-8+i*14),p+Vector2(6+i*5,-8+i*14),Color(0.5,0.7,0.75,0.13),1,true)
  else:
   var side = _territory(coord)
   var col = Color("78826c") if side == 1 else Color("8b7965") if side == 2 else Color("8b8d76")
   if c.terrain == "forest": col = col.darkened(0.16)
   if c.terrain == "mountain": col = Color("787c70")
   draw_colored_polygon(points,col.lightened(shade))
   if show_grid: outline(points,Color(0.12,0.19,0.19,0.2),0.8)
   if c.terrain == "forest":
    for offset in [Vector2(-10,5),Vector2(10,7),Vector2(0,-8)]: _tree(p+offset,Color("425c4b"))
   elif c.terrain == "mountain":
    _mountain(p+Vector2(-7,2),21)
    _mountain(p+Vector2(12,7),14)
   else:
    draw_circle(p+Vector2(13,11),1,Color(0.2,0.3,0.2,0.2))
   if paths.has(coord):
    draw_colored_polygon(points,Color(0.45,0.87,0.87,0.17))
    draw_circle(p,4,Color("b5ebdb"))
    draw_arc(p,12,0,TAU,24,Color(0.7,0.94,0.85,0.35),1,true)
  if interactive and coord == hovered and not busy: outline(points,Color(1,1,0.9,0.25),1)
 # Decorative supply routes.
 for pair in [[Vector2i(4,3),Vector2i(9,4)],[Vector2i(5,7),Vector2i(9,4)],[Vector2i(9,4),Vector2i(13,5)],[Vector2i(13,5),Vector2i(16,7)],[Vector2i(13,5),Vector2i(15,2)]]:
  var a = hex_pos(pair[0])
  var b = hex_pos(pair[1])
  var length = a.distance_to(b)
  for t in range(0,int(length),12): draw_line(a.lerp(b,t/length),a.lerp(b,minf((t+5)/length,1)),Color(0.9,0.86,0.67,0.22),2,true)
 # A frontier follows the central mountain range.
 for r in range(0,9):
  var a = hex_pos(Vector2i(10,r))+Vector2(-R,10)
  draw_line(a,a+Vector2(0,16),Color(0.94,0.84,0.64,0.3),2,true)
 for c in battle.cells:
  if c.city == "": continue
  var p = hex_pos(Vector2i(c.q,c.r))
  var color = BLUE if int(c.owner) == 1 else RED if int(c.owner) == 2 else Color("e4d6ad")
  _city_symbol(p,color,c.capital)
  var w: float = CN.get_string_size(c.city,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20
  box(Rect2(p.x-w/2,p.y+25,w,25),Color("263638"),color.darkened(0.28),3)
  center(c.city+ (""),Rect2(p.x-w/2,p.y+25,w,25),16,color)
 for troop in battle.units:
  var p = hex_pos(battle.pos(troop))
  _unit(p,troop)
  if interactive and not u.is_empty() and battle.can_attack(u,troop) and not busy:
   draw_arc(p,28,0,TAU,40,RED,2.5,true)
   for angle in [0,PI/2,PI,PI*1.5]: draw_line(p+Vector2(cos(angle),sin(angle))*25,p+Vector2(cos(angle),sin(angle))*34,RED,2,true)
 if interactive and battle.valid(selected):
  var p = hex_pos(selected)
  outline(hex_points(p,R-1),GOLD,3)
  outline(hex_points(p,R+3),Color(GOLD,0.25),1)
 # Map furniture.
 txt("北 境 战 区",Vector2(48,177),17,Color("c3d1c7"))
 txt("N O R T H E R N   T H E A T R E",Vector2(210,176),11,Color("92aaa9"),EN)
 txt("联军",Vector2(300,250),24,Color(0.85,0.95,0.87,0.25))
 txt("赤岩军团",Vector2(738,746),22,Color(0.95,0.85,0.72,0.3))
 txt("北",Vector2(1094,174),13,MUTED)
 draw_line(Vector2(1102,209),Vector2(1102,184),GOLD,2)
 draw_colored_polygon(PackedVector2Array([Vector2(1102,181),Vector2(1097,191),Vector2(1107,191)]),GOLD)
 txt("●  联军",Vector2(51,783),14,BLUE)
 txt("●  赤岩",Vector2(145,783),14,RED)
 txt("◆  中立城市",Vector2(239,783),14,Color("e4d6ad"))
 txt("地形影响机动与防御",Vector2(926,783),13,Color("afc1b8"))

func _territory(coord: Vector2i) -> int:
 if territory_cache.has(coord): return territory_cache[coord]
 var best = 999
 var owner = 0
 for c in battle.cells:
  if c.city == "": continue
  var d = battle.distance(coord,Vector2i(c.q,c.r))
  if d < best:
   best = d
   owner = int(c.owner)
 territory_cache[coord] = owner
 return owner

func _tree(p: Vector2, col: Color) -> void:
 draw_line(p+Vector2(0,2),p+Vector2(0,8),col.darkened(0.2),2)
 draw_colored_polygon(PackedVector2Array([p+Vector2(-7,4),p+Vector2(0,-10),p+Vector2(7,4)]),col)
 draw_line(p+Vector2(-6,3),p+Vector2(0,-9),col.lightened(0.17),1,true)

func _mountain(p: Vector2, h: float) -> void:
 draw_colored_polygon(PackedVector2Array([p+Vector2(-h*0.7,h*0.4),p+Vector2(0,-h),p+Vector2(h*0.8,h*0.4)]),Color("535f57"))
 draw_colored_polygon(PackedVector2Array([p+Vector2(0,-h),p+Vector2(h*0.8,h*0.4),p+Vector2(0,h*0.2)]),Color("6b7365"))
 draw_line(p+Vector2(-h*0.7,h*0.4),p+Vector2(0,-h),Color("a4a78b"),1,true)

func _city_symbol(p: Vector2, color: Color, capital: bool) -> void:
 draw_circle(p+Vector2(0,8),23,Color(0.04,0.09,0.1,0.35))
 for x in [-15,-5,5]:
  draw_rect(Rect2(p+Vector2(x,-2-abs(x)*0.3),Vector2(9,20+abs(x)*0.3)),Color("344344"))
  draw_line(p+Vector2(x,-3-abs(x)*0.3),p+Vector2(x+8,-3-abs(x)*0.3),color,2)
 draw_line(p+Vector2(-22,19),p+Vector2(22,19),color,2)
 if capital:
  draw_line(p+Vector2(18,10),p+Vector2(18,-27),color,2)
  draw_colored_polygon(PackedVector2Array([p+Vector2(18,-27),p+Vector2(36,-22),p+Vector2(18,-17)]),color)

func _unit(p: Vector2, u: Dictionary) -> void:
 var color = BLUE if u.side == 1 else RED
 var active: bool = u.side == 1 and (u.moves > 0 or not u.acted)
 draw_circle(p+Vector2(2,5),23,Color(0.01,0.035,0.04,0.38))
 box(Rect2(p.x-22,p.y-21,44,35),Color("203b40") if u.side == 1 else Color("493933"),color.darkened(0.3) if active or u.side == 2 else color.darkened(0.6),6,2)
 _silhouette(p+Vector2(0,-4),u.kind,color if active or u.side == 2 else color.darkened(0.38),0.76)
 var ratio = float(u.hp)/Rules.TROOPS[u.kind].hp
 box(Rect2(p.x-20,p.y+18,40,5),Color("243332"),Color.TRANSPARENT,2,0)
 box(Rect2(p.x-20,p.y+18,maxf(2,40*ratio),5),color if ratio > 0.35 else GOLD,Color.TRANSPARENT,2,0)
 if active: draw_circle(p+Vector2(22,-20),4,Color("d9eac4"))
 if u.general: _star(p+Vector2(-22,-20),7,GOLD)
 if int(u.id) == selected_id: draw_arc(p,29,0,TAU,40,Color(GOLD,0.6+sin(total_time*3)*0.2),2,true)

func _silhouette(p: Vector2, kind: String, color: Color, scale_factor: float = 1) -> void:
 draw_set_transform_matrix(art_transform * Transform2D(0,Vector2.ONE*scale_factor,0,p))
 if kind == "tank":
  box(Rect2(-22,1,44,14),color.darkened(0.26),Color.TRANSPARENT,5,0)
  for x in [-14,-4,6,16]: draw_circle(Vector2(x,8),3,color.darkened(0.55))
  draw_colored_polygon(PackedVector2Array([Vector2(-21,0),Vector2(-14,-8),Vector2(14,-8),Vector2(23,0)]),color)
  box(Rect2(-9,-16,23,11),color,Color.TRANSPARENT,3,0)
  draw_line(Vector2(7,-13),Vector2(31,-13),color,5)
 elif kind == "artillery":
  draw_circle(Vector2(-10,8),8,color.darkened(0.2))
  draw_circle(Vector2(8,8),8,color.darkened(0.2))
  draw_line(Vector2(-21,8),Vector2(18,0),color,4,true)
  draw_line(Vector2(-4,-1),Vector2(26,-19),color,7,true)
  draw_line(Vector2(-5,-3),Vector2(-13,-13),color,4,true)
 else:
  draw_circle(Vector2(-4,-14),7,color)
  draw_rect(Rect2(-12,-12,16,4),color)
  draw_colored_polygon(PackedVector2Array([Vector2(-10,-5),Vector2(2,-5),Vector2(8,11),Vector2(-14,11)]),color)
  draw_line(Vector2(-8,8),Vector2(-13,22),color,6,true)
  draw_line(Vector2(1,8),Vector2(8,22),color,6,true)
  draw_line(Vector2(0,2),Vector2(17,-7),color,5,true)
  draw_line(Vector2(13,6),Vector2(20,-22),color,3,true)
 draw_set_transform_matrix(art_transform)

func _star(p: Vector2, radius: float, color: Color) -> void:
 var points = PackedVector2Array()
 for i in 10:
  var angle = -PI/2+i*PI/5
  points.append(p+Vector2(cos(angle),sin(angle))*radius*(1 if i%2 == 0 else 0.45))
 draw_colored_polygon(points,color)

func _emblem(p: Vector2, radius: float, color: Color) -> void:
 outline(hex_points(p,radius),color,2)
 _star(p,radius*0.63,color)

func _compass(p: Vector2, color: Color) -> void:
 draw_arc(p,40,0,TAU,60,Color(color,0.4),1,true)
 draw_colored_polygon(PackedVector2Array([p+Vector2(0,-50),p+Vector2(8,0),p+Vector2(0,50),p+Vector2(-8,0)]),color)
 draw_colored_polygon(PackedVector2Array([p+Vector2(-30,0),p+Vector2(0,-6),p+Vector2(30,0),p+Vector2(0,6)]),color.darkened(0.2))
 center("N",Rect2(p.x-15,p.y-80,30,25),16,color,EN)

func _sidebar() -> void:
 txt("作 战 指 令",Vector2(1190,180),17,GOLD)
 txt("夺取敌方首都 · 黑石城",Vector2(1190,218),24)
 txt("守住白石城，在 35 回合内完成目标",Vector2(1190,248),16,MUTED)
 draw_line(Vector2(1190,270),Vector2(1550,270),LINE)
 var u = battle.unit_by_id(selected_id)
 var c = battle.cell(selected)
 if not u.is_empty():
  var data: Dictionary = Rules.TROOPS[u.kind]
  var col = BLUE if u.side == 1 else RED
  box(Rect2(1190,290,76,76),Color("243b3e"),col.darkened(0.3),8)
  _silhouette(Vector2(1227,326),u.kind,col,1.1)
  txt(data.name,Vector2(1283,322),27)
  txt("联军  /  第 %02d 军团" % int(u.id) if u.side == 1 else "赤岩军团  /  敌对",Vector2(1283,352),16,col)
  txt("兵力",Vector2(1190,399),16,MUTED)
  txt("%d / %d" % [u.hp,data.hp],Vector2(1400,399),18,col,EN)
  box(Rect2(1190,412,360,7),BG,Color.TRANSPARENT,3,0)
  box(Rect2(1190,412,360*float(u.hp)/data.hp,7),col,Color.TRANSPARENT,3,0)
  _stat(Rect2(1190,442,112,64),"火力",str(data.attack+ (12 if u.general else 0)))
  _stat(Rect2(1314,442,112,64),"机动",str(u.moves)+" / "+str(data.move))
  _stat(Rect2(1438,442,112,64),"射程",str(data.range))
  if u.side == 1:
   txt("指挥官 · 林岚  /  火力 +12" if u.general else "未任命指挥官",Vector2(1190,540),17,GOLD if u.general else MUTED)
   button("general","任命指挥官 · 120",Rect2(1190,557,360,43),false,not busy and not u.general and battle.gold[1] >= 120,18)
   button("repair","城市补给 +35 兵力 · 50",Rect2(1190,612,360,43),false,not busy and c.get("city","") != "" and int(c.get("owner",0)) == 1 and u.hp < data.hp and not u.repaired and battle.gold[1] >= 50,18)
   if c.get("city","") != "" and int(c.owner) == 1:
    button("city","查看城市 / 招募部队  →",Rect2(1190,667,360,43),false,not busy,18)
   else:
    txt("本回合已攻击" if u.acted else "可攻击 · 点选红色标记的敌军",Vector2(1190,691),17,MUTED if u.acted else col)
   txt("蓝色格可移动；攻击后结束该部队行动",Vector2(1190,752),15,MUTED)
  else:
   txt("敌军情报",Vector2(1190,548),17,GOLD)
   txt("利用地形掩护，集中火力逐个击破。",Vector2(1190,584),18,MUTED)
   txt("坦克克制步兵，火炮擅长打击装甲。",Vector2(1190,620),17,MUTED)
   _terrain_info(c,684)
 elif not c.is_empty() and c.city != "":
  var col = BLUE if int(c.owner) == 1 else RED if int(c.owner) == 2 else GOLD
  txt(c.city + (" · 首都" if c.capital else ""),Vector2(1190,321),30,col)
  txt(["中立城市 · 派部队进入即可占领","联军控制 · 每回合 +35 军费 / +1 工业","敌方控制 · 消灭守军后派部队进入"][int(c.owner)],Vector2(1190,356),16,MUTED)
  if int(c.owner) == 1:
   txt("招募部队",Vector2(1190,404),20,GOLD)
   var i = 0
   for kind in ["infantry","tank","artillery"]:
    var d: Dictionary = Rules.TROOPS[kind]
    box(Rect2(1190,423+i*91,360,80),Color("203438"),LINE,6)
    _silhouette(Vector2(1227,460+i*91),kind,BLUE,0.7)
    txt(d.name,Vector2(1267,452+i*91),20)
    txt("%d 军费 · %d 工业" % [d.cost,d.steel],Vector2(1267,481+i*91),15,MUTED)
    button("recruit_"+kind,"招募",Rect2(1464,440+i*91,70,45),false,not busy and battle.gold[1] >= d.cost and battle.steel[1] >= d.steel,17)
    i += 1
   txt("新兵在城市或相邻空地部署，下回合行动",Vector2(1190,740),15,MUTED)
  else:
   _city_symbol(Vector2(1360,468),col,c.capital)
   txt("夺取城市，扩大补给线。",Vector2(1190,574),21)
   txt("敌军驻守时无法直接占领；",Vector2(1190,617),18,MUTED)
   txt("先用炮兵削弱，再让步兵或坦克推进。",Vector2(1190,651),17,MUTED)
 else:
  txt("战场态势",Vector2(1190,319),26)
  txt("联军",Vector2(1190,363),18,BLUE)
  txt("%d 座城市" % battle.city_count(1),Vector2(1445,363),18,BLUE)
  txt("赤岩军团",Vector2(1190,400),18,RED)
  txt("%d 座城市" % battle.city_count(2),Vector2(1445,400),18,RED)
  txt("前线战报",Vector2(1190,458),17,GOLD)
  for i in mini(5,battle.logbook.size()):
   var s: String = battle.logbook[i]
   if s.length() > 23: s = s.substr(0,22)+"…"
   txt(s,Vector2(1190,493+i*37),16,MUTED if i > 0 else INK)
  if not c.is_empty(): _terrain_info(c,713)
  else:
   txt("点选地图上的军团或城市，",Vector2(1190,724),18,INK)
   txt("查看情报并下达作战指令。",Vector2(1190,755),18,MUTED)

func _stat(rect: Rect2, label: String, value: String) -> void:
 box(rect,Color("21363a"),LINE,5)
 center(label,Rect2(rect.position,Vector2(rect.size.x,25)),14,MUTED)
 center(value,Rect2(rect.position+Vector2(0,25),Vector2(rect.size.x,34)),22,INK,EN)

func _terrain_info(c: Dictionary, y: float) -> void:
 var labels = {"plain":"平原 · 机动消耗 1","forest":"森林 · 机动消耗 2 / 减伤 20%","mountain":"山地 · 仅步兵通行 / 减伤 25%","water":"海域 · 本战役陆军无法通行"}
 txt(labels[c.terrain],Vector2(1190,y),16,MUTED)

func _draw_modal() -> void:
 buttons.clear()
 draw_rect(Rect2(0,0,1600,900),Color(0.015,0.03,0.035,0.86))
 box(Rect2(365,112,870,676),PANEL,Color("6c7060"),12)
 _emblem(Vector2(419,168),22,GOLD)
 if modal == "help":
  txt("作战手册",Vector2(460,180),31)
  txt("掌握补给线，掌握战争。",Vector2(409,228),20,GOLD)
  var entries = [
   ["01  下达命令","点选我方部队；蓝色格移动，红色标记的敌军可攻击。"],
   ["02  兵种协同","步兵占领山地；坦克机动快；火炮可攻击三格内目标。"],
   ["03  城市与经济","进入空城即可占领。每城每回合提供 35 军费和 1 工业。"],
   ["04  招募与补给","点我方城市招募；驻城部队可花 50 军费恢复 35 兵力。"],
   ["05  战斗与指挥","攻击结束机动；近战有反击。120 军费任命唯一指挥官。"],
   ["06  胜利条件","35 回合内进入黑石城获胜；白石城失守或超时则失败。"]]
  for i in entries.size():
   txt(entries[i][0],Vector2(409,282+i*65),20,INK)
   txt(entries[i][1],Vector2(409,310+i*65),17,MUTED)
  txt("进度自动保存 · 支持触控 · 无联网和账号要求",Vector2(409,696),17,GOLD)
  button("close","了解，继续  →",Rect2(893,717,296,48),true,true,20)
 elif modal == "pause":
  txt("战役暂停",Vector2(460,180),31)
  txt("第 %d 回合 · 进度已自动保存" % battle.turn,Vector2(409,237),22,MUTED)
  button("close","返回战场",Rect2(500,291,600,66),true,true,25)
  button("help","作战手册",Rect2(500,380,600,60),false,true,23)
  button("grid","隐藏网格" if show_grid else "显示网格",Rect2(500,463,600,60),false,true,23)
  button("menu","保存并返回主菜单",Rect2(500,546,600,60),false,true,23)
  txt("快捷键：Esc 暂停   /   Space 结束回合",Vector2(500,707),18,MUTED)
 elif modal == "new_confirm":
  txt("开始新的征服？",Vector2(460,180),31)
  txt("新战役将替换当前自动存档。",Vector2(409,277),25,MUTED)
  txt("你可以先返回主菜单，继续未完成的战役。",Vector2(409,327),22,MUTED)
  button("close","返回",Rect2(500,600,270,66),false,true,23)
  button("confirm_new","开始新战役",Rect2(800,600,300,66),true,true,23)
 elif modal == "result":
  var victory = battle.result == 1
  txt("战 役 胜 利" if victory else "战 役 失 利",Vector2(460,180),36,GOLD if victory else RED)
  txt("黑石城的旗帜已为你升起。" if victory else "前线失守，但指挥官的征途尚未结束。",Vector2(409,266),27)
  txt("你重新书写了北境的边界。" if victory else "夺城获取补给，集中火力，再次进军。",Vector2(409,315),21,MUTED)
  _stat(Rect2(440,373,220,110),"作战回合",str(battle.turn))
  _stat(Rect2(690,373,220,110),"占领城市",str(battle.city_count(1)))
  _stat(Rect2(940,373,220,110),"歼灭军团",str(battle.kills))
  txt("%s  /  %s" % [["新兵","指挥官","老兵"][battle.difficulty],["北境破晓","钢铁洪流"][battle.scenario]],Vector2(440,550),23,GOLD)
  button("menu","返回主菜单",Rect2(440,650,340,65),false,true,23)
  button("confirm_new","再次出征  →",Rect2(810,650,350,65),true,true,23)

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   if modal != "" and modal != "result": modal = ""
   elif screen == "battle" and not busy:
    modal = "pause"
    _save()
  if event.keycode == KEY_SPACE and screen == "battle" and modal == "" and not busy: _end_turn()
 if event is InputEventScreenTouch and event.pressed:
  last_touch = total_time
  _click(event.position)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and total_time-last_touch > 0.3:
  _click(get_local_mouse_position())
 if event is InputEventMouseMotion and screen == "battle": hovered = _coord(get_local_mouse_position())

func _click(p: Vector2) -> void:
 for i in range(buttons.size()-1,-1,-1):
  var b = buttons[i]
  if b.rect.has_point(p):
   if b.enabled:
    _beep()
    _action(b.id)
   return
 if modal != "" or screen != "battle" or busy or battle.result != 0: return
 var coord = _coord(p)
 if not battle.valid(coord): return
 _select_cell(coord)

func _coord(p: Vector2) -> Vector2i:
 if not Rect2(25,185,1118,588).has_point(p): return Vector2i(-1,-1)
 var best = Vector2i(-1,-1)
 var closest = R
 for c in battle.cells:
  var v = Vector2i(c.q,c.r)
  var d = hex_pos(v).distance_to(p)
  if d < closest:
   closest = d
   best = v
 return best

func _select_cell(coord: Vector2i) -> void:
 var u = battle.unit_by_id(selected_id)
 var target = battle.unit_at(coord)
 if not u.is_empty() and u.side == 1 and battle.can_attack(u,target):
  var from = hex_pos(battle.pos(u))
  var hit = battle.attack(u,target)
  effects.append({"from":from,"to":hex_pos(coord),"text":"−%d" % hit.damage,"life":1.0})
  _beep(160,0.13)
  _notice("造成 %d 伤害%s" % [hit.damage," · 反击 %d" % hit.counter if hit.counter else ""])
  _save()
  _check_result()
  return
 if not u.is_empty() and u.side == 1 and target.is_empty() and battle.move_unit(u,coord):
  selected = coord
  _beep(500,0.04)
  _save()
  _check_result()
  return
 selected = coord
 selected_id = int(target.id) if not target.is_empty() else -1
 _beep(420,0.035)
 if not target.is_empty() and target.side == 1 and target.moves == 0 and target.acted: _notice("该部队已行动完毕，下回合恢复")

func _action(id: String) -> void:
 match id:
  "new":
   if saved_available: modal = "new_confirm"
   else: _new_game()
  "confirm_new": _new_game()
  "continue": _load_game()
  "mission": mission = 1-mission
  "help": modal = "help"
  "close": modal = ""
  "pause":
   _save()
   modal = "pause"
  "menu":
   _save()
   screen = "menu"
   modal = ""
  "grid": show_grid = not show_grid
  "sound": sound_on = not sound_on
  "end": _end_turn()
  "city": selected_id = -1
  "repair":
   var u = battle.unit_by_id(selected_id)
   if not u.is_empty() and battle.repair(u):
    _notice("战地补给完成 · 兵力 +35")
    _save()
  "general":
   var u = battle.unit_by_id(selected_id)
   if not u.is_empty() and battle.appoint(u):
    _notice("林岚已就任指挥官 · 火力 +12 / 减伤 15%")
    _save()
   else: _notice("每方仅能任命一位指挥官")
  _:
   if id.begins_with("difficulty"): difficulty = int(id.right(1))
   if id.begins_with("recruit_"):
    var kind = id.trim_prefix("recruit_")
    var u = battle.recruit(selected,kind)
    if u.is_empty(): _notice("无法招募：周边没有可部署空地或补给不足")
    else:
     _notice("%s已部署，下回合可以行动" % Rules.TROOPS[kind].name)
     effects.append({"to":hex_pos(battle.pos(u)),"text":"增援","life":1.0})
     _save()

func _new_game() -> void:
 battle.setup(difficulty,mission)
 screen = "battle"
 selected = Vector2i(6,3)
 selected_id = 2
 modal = ""
 busy = false
 _save()
 _notice("攻占中立城市河间，建立前线补给基地")

func _end_turn() -> void:
 if busy or battle.result != 0 or battle.phase != 1: return
 _save()
 busy = true
 selected_id = -1
 selected = Vector2i(-1,-1)
 battle.begin_enemy()
 _save()
 await _run_enemy()

func _run_enemy() -> void:
 var ids: Array = []
 for u in battle.units:
  if u.side == 2: ids.append(int(u.id))
 for id in ids:
  if battle.result != 0: break
  await get_tree().create_timer(0.27).timeout
  var step = battle.ai_step(id)
  if step.get("attack",false):
   effects.append({"from":hex_pos(step.from),"to":hex_pos(step.to),"text":"−%d" % step.damage,"life":1.0})
   _beep(130,0.09)
 battle.finish_enemy()
 busy = false
 _save()
 if battle.result == 0: _notice("第 %d 回合 · 补给已到达，全军待命" % battle.turn)
 _check_result()

func _check_result() -> void:
 if battle.result != 0:
  modal = "result"
  _save()

func _save() -> void:
 if screen != "battle" or busy: return
 # Atomic replacement prevents a partially written save on app suspension.
 var file = FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
 if file == null:
  _notice("自动保存失败，请检查设备存储空间")
  return
 file.store_string(JSON.stringify(battle.snapshot()))
 file.close()
 var error = DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)
 saved_available = error == OK
 if not saved_available: _notice("自动保存失败，请检查设备存储空间")

func _load_game() -> void:
 var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not parsed is Dictionary or not battle.restore(parsed):
  _notice("存档无法读取，可以开始新的战役")
  return
 screen = "battle"
 selected_id = -1
 selected = Vector2i(-1,-1)
 modal = ""
 if battle.phase == 2 and battle.result == 0:
  # A suspended enemy turn is safely completed without replaying earlier actions.
  battle.finish_enemy()
  _save()
 _check_result()
 _notice("已恢复第 %d 回合的战役" % battle.turn)

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST: _save()
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if modal != "" and modal != "result": modal = ""
  elif screen == "battle" and not busy:
   _save()
   modal = "pause"

func _notice(message: String) -> void:
 toast = message
 toast_time = 3.4

func _beep(frequency: float = 660, duration: float = 0.04) -> void:
 if not sound_on or not is_instance_valid(audio): return
 var sample_rate = 22050
 var n = int(sample_rate*duration)
 var bytes = PackedByteArray()
 bytes.resize(n*2)
 for i in n:
  var envelope = sin(PI*float(i)/n)*0.08
  bytes.encode_s16(i*2,int(sin(TAU*frequency*i/sample_rate)*envelope*32767))
 var wav = AudioStreamWAV.new()
 wav.format = AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate = sample_rate
 wav.data = bytes
 audio.stream = wav
 audio.play()

func _ui_test() -> void:
 sound_on = false
 _new_game()
 await get_tree().process_frame
 assert(screen == "battle" and battle.units.size() == 10)
 var u = battle.unit_by_id(2)
 var paths = battle.reachable(u)
 assert(not paths.is_empty())
 _select_cell(paths.keys()[0])
 assert(battle.pos(u) == selected)
 selected = Vector2i(4,3)
 selected_id = -1
 _action("recruit_infantry")
 assert(battle.units.size() == 11)
 _save()
 _load_game()
 assert(battle.units.size() == 11)
 await _end_turn()
 assert(battle.turn == 2 and battle.phase == 1 and not busy)
 _action("pause")
 assert(modal == "pause")
 _action("menu")
 assert(screen == "menu")
 print("UI_SMOKE_OK: move, recruit, save/resume, enemy turn, pause/menu")
 get_tree().quit()
