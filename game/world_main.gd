extends Control
const Rules = preload("res://game/world_battle.gd")
const MapView = preload("res://game/world_view.gd")
const CN = preload("res://assets/fonts/Chinese.ttc")
const EN = preload("res://assets/fonts/Interface.ttf")
const SERIF = preload("res://assets/fonts/Title.ttf")
const BG=Color("161e22")
const INK=Color("ece6d6")
const GOLD=Color("d9b678")
const MUTED=Color("9baba8")
const LINE=Color("57615a")
const SAVE="user://world_campaign_v2.json"
var battle=Rules.new()
var world
var screen="menu"
var modal=""
var buttons=[]
var faction=1
var difficulty=1
var selected=-1
var unit_id=-1
var busy=false
var notice=""
var notice_time=0.0
var has_save=false
var atlas: Texture2D
var terrain: Texture2D
var elite_atlas: Texture2D
var pointer_time=-10.0
var clock=0.0

func _ready():
 battle.setup(faction,difficulty)
 world=MapView.new()
 world.position=Vector2(24,132)
 world.size=Vector2(1164,654)
 world.z_index=-1
 world.model=battle
 world.province_clicked.connect(_select)
 add_child(world)
 world.visible=false
 if ResourceLoader.exists("res://assets/art/units.png"): atlas=load("res://assets/art/units.png")
 if ResourceLoader.exists("res://assets/art/elites.png"): elite_atlas=load("res://assets/art/elites.png")
 if ResourceLoader.exists("res://assets/world/map.png"): terrain=load("res://assets/world/map.png")
 has_save=FileAccess.file_exists(SAVE)
 var args=OS.get_cmdline_user_args()
 if "--battle" in args: _new()
 for view in ["tech","factions","cheats","recruit"]:
  if ("--"+view) in args:
   _new()
   modal=view
 if "--capture" in args:
  await get_tree().create_timer(1.5).timeout
  get_viewport().get_texture().get_image().save_png("/workspace/artifacts/v02-"+(modal if modal!="" else screen)+".png")
  get_tree().quit()
 if "--ui-test" in args: await _ui_test()

func _process(delta):
 clock+=delta
 notice_time=maxf(0,notice_time-delta)
 if world:
  world.enabled=not busy and modal==""
  world.selected=selected
  world.selected_unit=unit_id
 queue_redraw()

func text(s: String,p: Vector2,n: int=20,c: Color=INK,font: Font=CN):
 draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,n,c)

func centered(s: String,r: Rect2,n: int=20,c: Color=INK,font: Font=CN):
 var w=font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,n).x
 text(s,Vector2(r.position.x+(r.size.x-w)/2,r.position.y+r.size.y/2+n*0.35),n,c,font)

func panel(r: Rect2,fill: Color=Color("243035"),edge: Color=LINE):
 draw_rect(r,fill)
 for i in 16:
  draw_rect(Rect2(r.position+Vector2(0,i*r.size.y/16),Vector2(r.size.x,r.size.y/16)),Color(0,0,0,i*0.003))
 draw_rect(r,edge,false,1)
 draw_line(r.position+Vector2(1,1),r.position+Vector2(r.size.x-1,1),edge.lightened(0.15),1)
 draw_line(r.position+Vector2(1,r.size.y-2),r.end-Vector2(1,2),Color(0,0,0,0.3),1)

func button(id: String,label: String,r: Rect2,primary: bool=false,active: bool=true,n: int=20):
 var hover=r.has_point(get_local_mouse_position()) and active
 var col=Color("a68a50") if primary else Color("344346")
 if hover: col=col.lightened(0.12)
 if not active: col=Color("252f32")
 panel(r,col,GOLD if primary else LINE)
 centered(label,r,n,Color("131c20") if primary else INK if active else Color("647572"))
 buttons.append({"id":id,"r":r,"active":active})

func faction_color(side: int) -> Color:
 return Color("aaa994") if side==0 else Color(Rules.FACTIONS[side].color)

func faction_name(side: int) -> String:
 return "中立地区" if side==0 else str(Rules.FACTIONS[side].name)

func _draw():
 buttons.clear()
 if screen=="menu": _menu()
 else: _battle_ui()
 if modal!="": _modal()
 if notice_time>0:
  var width=maxf(520,CN.get_string_size(notice,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+50)
  panel(Rect2(800-width/2,826 if modal!="" else 789,width,43),Color("172b30"),GOLD)
  centered(notice,Rect2(800-width/2,826 if modal!="" else 789,width,43),19)

func _menu():
 draw_rect(Rect2(0,0,1600,900),BG)
 if terrain: draw_texture_rect(terrain,Rect2(-280,-60,2400,1200),false,Color(0.8,0.88,0.8))
 draw_rect(Rect2(0,0,1600,900),Color(0.015,0.035,0.04,0.63))
 for i in 40:
  draw_rect(Rect2(i*25,0,25,900),Color(0.04,0.065,0.075,0.88*(1-float(i)/40)))
 text("IRON MERIDIAN  /  CONQUEST EDITION",Vector2(74,68),17,GOLD,EN)
 text("铁幕前线",Vector2(68,195),78)
 text("全 球 征 服",Vector2(76,250),31,GOLD)
 draw_line(Vector2(76,278),Vector2(340,278),GOLD,2)
 text("从一座首都，到整个世界。",Vector2(76,325),27)
 text("真实地理  ·  八方势力  ·  科技与专属军团",Vector2(76,365),20,MUTED)
 panel(Rect2(1040,91,484,257),Color(0.08,0.13,0.15,0.91),Color("8b815f"))
 text("1940",Vector2(1070,173),64,GOLD,SERIF)
 text("世界沙盘 / 自由征服",Vector2(1070,215),26)
 text("68 个战略地区 · 8 个可选势力",Vector2(1070,258),20,MUTED)
 text("真实地理，架空多方战争；各势力独立行动",Vector2(1070,301),18,MUTED)
 text("选择你的势力",Vector2(76,423),21,GOLD)
 for side in range(1,9):
  var col=(side-1)%4
  var row=(side-1)/4
  var r=Rect2(76+col*366,444+row*116,348,100)
  panel(r,Color("253438") if faction!=side else Color("455047"),GOLD if faction==side else LINE)
  draw_rect(Rect2(r.position+Vector2(17,20),Vector2(7,58)),faction_color(side))
  text(faction_name(side),r.position+Vector2(40,37),25)
  var elite=Rules.FACTIONS[side].elite
  text("专属 · "+str(Rules.TROOPS[elite].name),r.position+Vector2(40,71),17,MUTED)
  buttons.append({"id":"faction:"+str(side),"r":r,"active":true})
 text(str(Rules.FACTIONS[faction].bonus),Vector2(76,708),20,GOLD)
 button("difficulty","难度："+["新兵","指挥官","老兵"][difficulty],Rect2(76,745,260,60),false,true,21)
 button("new","开始征服     →",Rect2(356,745,520,60),true,true,26)
 button("resume","继续存档",Rect2(896,745,300,60),false,has_save,24)
 button("help","作战手册",Rect2(1216,745,308,60),false,true,22)
 text("v0.2   /   离线单机   /   可开启单机修改器",Vector2(76,857),17,MUTED)

func _battle_ui():
 panel(Rect2(24,22,1552,90),Color("273332"))
 draw_rect(Rect2(24,22,7,90),faction_color(battle.player))
 text("铁幕前线",Vector2(48,58),25)
 text(faction_name(battle.player)+" · 第 %02d 回合"%battle.turn,Vector2(48,91),18,GOLD)
 _resource(300,"军费",int(battle.gold[battle.player]),GOLD)
 _resource(493,"工业",int(battle.steel[battle.player]),Color("aec8bf"))
 _resource(663,"科研",int(battle.science[battle.player]),Color("8cb7d2"))
 button("tech","科技研究",Rect2(860,43,151,47),false,not busy,19)
 button("factions","势力",Rect2(1024,43,110,47),false,true,19)
 button("cheats","修改器",Rect2(1147,43,125,47),false,not busy,19)
 button("help","手册",Rect2(1285,43,110,47),false,true,19)
 button("pause","菜单  ≡",Rect2(1408,43,146,47),false,not busy,19)
 button("zoom_out","−",Rect2(1030,148,44,42),false,true,26)
 button("zoom_in","+",Rect2(1082,148,44,42),false,true,26)
 button("overview","◎",Rect2(1134,148,40,42),false,true,25)
 panel(Rect2(1208,132,368,654),Color("263331"))
 _sidebar()
 panel(Rect2(24,810,1164,67),Color("233333"))
 var capital_count=0
 for p in battle.provinces:
  if p.capital and int(p.owner)==battle.player:capital_count+=1
 text("战役目标",Vector2(44,837),15,GOLD)
 text("控制全部首都  %d / 8"%capital_count,Vector2(44,865),20)
 var recent: String = battle.logbook[0] if not battle.logbook.is_empty() else "点选军团，下达命令"
 if recent.length()>33:recent=recent.substr(0,32)+"…"
 text(recent,Vector2(365,849),18,MUTED)
 var modified=false
 for value in battle.cheats.values():
  if value:modified=true
 if modified: text("修改器已启用",Vector2(1015,850),17,GOLD)
 button("end","AI 行动中…" if busy else "结束回合   →",Rect2(1208,810,368,67),true,not busy and battle.result==0,24)

func _resource(x: float,label: String,value: int,col: Color):
 text(label,Vector2(x,52),16,MUTED)
 text(str(value),Vector2(x,89),29,col,EN)

func _sidebar():
 if selected<0:
  text("司令部",Vector2(1230,172),27,GOLD)
  text("全球战况",Vector2(1230,209),19,MUTED)
  for side in range(1,9):
   var y=250+(side-1)*49
   draw_circle(Vector2(1239,y-5),5,faction_color(side))
   text(faction_name(side),Vector2(1256,y),20)
   var count=0
   for p in battle.provinces:
    if int(p.owner)==side:count+=1
   text(str(count)+" 地区",Vector2(1465,y),17,MUTED)
  text("点选城市或军团查看详情",Vector2(1230,717),18,GOLD)
  text("港口之间的虚线为海运航线",Vector2(1230,751),16,MUTED)
  return
 var p=battle.province(selected)
 text(p.name,Vector2(1230,175),30)
 text(faction_name(int(p.owner))+(" / 首都" if p.capital else " / 港口" if p.coastal else " / 内陆"),Vector2(1230,208),18,faction_color(int(p.owner)))
 draw_line(Vector2(1230,230),Vector2(1554,230),LINE)
 var u=battle.unit_by_id(unit_id)
 if not u.is_empty():
  var stats=battle.unit_stats(u)
  _portrait(u.kind,Rect2(1260,233,260,150))
  text(stats.name,Vector2(1230,408),27)
  text(faction_name(int(u.side))+"军团",Vector2(1230,440),17,faction_color(int(u.side)))
  text("兵力 %d / %d"%[u.hp,stats.hp],Vector2(1230,477),19)
  draw_rect(Rect2(1230,489,324,7),BG)
  draw_rect(Rect2(1230,489,324*clampf(float(u.hp)/stats.hp,0,1),7),faction_color(int(u.side)))
  _stat(Rect2(1230,516,101,65),"火力",str(stats.attack))
  _stat(Rect2(1342,516,101,65),"机动",str(u.moves))
  _stat(Rect2(1454,516,100,65),"射程",str(stats.range))
  if int(u.side)==battle.player:
   button("repair","补给 / 恢复兵力",Rect2(1230,603,324,46),false,not busy,19)
   button("recruit","招募与专属军团",Rect2(1230,663,324,46),false,int(p.owner)==battle.player and not busy,19)
   text("已攻击" if u.acted else "可攻击红圈内的敌军",Vector2(1230,748),17,MUTED)
  else:
   text("敌军情报",Vector2(1230,621),19,GOLD)
   text("集中火力，攻占其首都迫使其投降。",Vector2(1230,661),16,MUTED)
   text("科技升级可强化全部现役部队。",Vector2(1230,704),17,MUTED)
 else:
  text("地区指挥部",Vector2(1230,280),24,GOLD)
  text("城市提供军费、工业与科研。",Vector2(1230,326),18,MUTED)
  text("驻军进入空城即可占领。",Vector2(1230,361),18,MUTED)
  if p.capital:
   text("战略首都",Vector2(1230,429),26)
   text("失守会导致所属势力投降。",Vector2(1230,469),18,MUTED)
  if int(p.owner)==battle.player:
   button("recruit","招募部队   →",Rect2(1230,545,324,58),true,not busy,22)
   button("tech","发展科技",Rect2(1230,621,324,50),false,not busy,20)
  else:
   text("先击败守军，再移动至此地区。",Vector2(1230,597),17,MUTED)
  text("控制区："+str(p.terrain),Vector2(1230,744),17,MUTED)

func _portrait(kind: String,r: Rect2):
 if not atlas:return
 var texture=elite_atlas if kind in world.ELITES and elite_atlas else atlas
 var index=world.ELITES.find(kind) if kind in world.ELITES else world.sprite_index(kind)
 var cell_size=texture.get_size()/Vector2(4,2)
 var w=minf(r.size.x,r.size.y)*1.05
 draw_texture_rect_region(texture,Rect2(r.get_center()-Vector2(w,w)/2,Vector2(w,w)),Rect2(Vector2(index%4,index/4)*cell_size,cell_size))

func _stat(r: Rect2,label: String,value: String):
 panel(r,Color("1d292b"),Color("414e4b"))
 centered(label,Rect2(r.position,Vector2(r.size.x,26)),15,MUTED)
 centered(value,Rect2(r.position+Vector2(0,26),Vector2(r.size.x,34)),23,INK,EN)

func _modal():
 buttons.clear()
 draw_rect(Rect2(0,0,1600,900),Color(0.025,0.04,0.045,0.89))
 panel(Rect2(140,90,1320,720),Color("263230"),Color("94815b"))
 var titles={"tech":"科技研究院","factions":"势力与世界战况","cheats":"单机修改器","recruit":"军团招募中心","help":"征服作战手册","pause":"战役暂停","replace":"开始新的征服？","result":"征服胜利" if battle.result==1 else "战役失利"}
 text(titles.get(modal,"指挥部"),Vector2(174,145),33,GOLD)
 if modal not in ["result","replace"]:button("close","关闭 ×",Rect2(1300,111,127,45),false,true,20)
 draw_line(Vector2(174,166),Vector2(1427,166),LINE)
 match modal:
  "tech": _tech()
  "cheats": _cheats()
  "factions": _factions()
  "recruit": _recruit()
  "help": _help()
  "pause":
   text("当前进度已自动保存",Vector2(174,230),22,MUTED)
   button("close","继续征服",Rect2(480,302,640,66),true,true,25)
   button("overview_close","查看世界全图",Rect2(480,397,640,62),false,true,23)
   button("menu","保存并返回主菜单",Rect2(480,489,640,62),false,true,23)
   text("每个玩家动作后自动保存；退出 AI 回合会恢复至行动前。",Vector2(350,682),21,MUTED)
  "replace":
   text("新战役将替换世界征服存档。",Vector2(174,251),25)
   text("本次选择："+faction_name(faction),Vector2(174,305),23,GOLD)
   button("close","取消",Rect2(470,575,300,65),false,true,23)
   button("new_confirm","开始新战役",Rect2(810,575,320,65),true,true,23)
  "result":
   text("你已控制全部战略首都。" if battle.result==1 else "首都失守，或战役已到达回合期限。",Vector2(174,264),30)
   text("完成回合：%d"%battle.turn,Vector2(174,338),25,GOLD)
   text("势力："+faction_name(battle.player),Vector2(174,392),25)
   button("menu","返回主菜单",Rect2(470,603,660,67),true,true,25)

func _tech():
 text("军费 %d   ·   科研 %d"%[battle.gold[battle.player],battle.science[battle.player]],Vector2(174,206),20,MUTED)
 var i=0
 for key in Rules.TECH:
  var d=Rules.TECH[key]
  var r=Rect2(174+(i%3)*422,233+(i/3)*238,396,215)
  var level=int(battle.tech[battle.player][key])
  panel(r,Color("202d2d"),LINE)
  text(d.name,r.position+Vector2(20,37),25)
  for j in 3:
   draw_rect(Rect2(r.position+Vector2(20+j*32,57),Vector2(24,5)),GOLD if j<level else Color("4a5750"))
  var desc: String=d.desc
  # Short descriptions in the rules are intentionally wrapped for phone screens.
  var lines=_wrap(desc,352,17)
  for line in lines.size():text(lines[line],r.position+Vector2(20,96+line*26),17,MUTED)
  var cost=battle.research_cost(key)
  var label="已满级" if level>=3 else "升级  %d军费 / %d科研"%[cost.x,cost.y]
  button("research:"+key,label,Rect2(r.position+Vector2(18,158),Vector2(360,42)),level<3,level<3,17)
  i+=1
 text("武器科技达到 II 级可解锁本势力专属军团。研究效果立即应用于现役和新招募部队。",Vector2(174,768),18,GOLD)

func _wrap(s: String,width: float,font_size: int) -> Array:
 var lines=[]
 var current=""
 for ch in s:
  if CN.get_string_size(current+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width and current!="" and not ch in ["%","I","级","点"]:
   lines.append(current);current=""
  current+=ch
 if current!="":lines.append(current)
 return lines

func _cheats():
 text("仅影响当前离线战役。开关和修改后的进度会一起保存。",Vector2(174,210),20,MUTED)
 var opts=[
  ["resources","无限资源","立即补充军费、工业与科研，行动后自动补足。"],
  ["invincible","我军无敌","我方部队不承受战斗伤害。"],
  ["unlimited_actions","无限行动","移动、攻击后可继续行动；AI 正常消耗行动。"],
  ["instant_research","免费研究","所选科技直接升至 III 级，不消耗军费和科研。"]]
 for i in 4:
  var y=249+i*110
  panel(Rect2(174,y,1252,92),Color("202d2d"),LINE)
  text(opts[i][1],Vector2(197,y+35),25)
  text(opts[i][2],Vector2(197,y+69),18,MUTED)
  var active=bool(battle.cheats[opts[i][0]])
  button("cheat:"+opts[i][0],"已开启" if active else "已关闭",Rect2(1234,y+22,170,48),active,true,21)
 text("修改器启用时，战场底部持续显示标记；关闭开关不会撤回已获得的资源或科技。",Vector2(174,757),18,GOLD)

func _factions():
 for side in range(1,9):
  var r=Rect2(174+((side-1)%2)*638,202+((side-1)/2)*134,614,116)
  panel(r,Color("202d2d"),faction_color(side).darkened(0.3))
  var count=0
  var armies=0
  for p in battle.provinces:
   if int(p.owner)==side:count+=1
  for u in battle.units:
   if int(u.side)==side:armies+=1
  text(faction_name(side)+(" / 玩家" if side==battle.player else " / AI"),r.position+Vector2(18,33),24,faction_color(side))
  text("地区 %d  ·  军团 %d"%[count,armies],r.position+Vector2(18,66),18,MUTED)
  text("专属："+str(Rules.TROOPS[Rules.FACTIONS[side].elite].name),r.position+Vector2(18,96),18)
  button("focus:"+str(side),"定位",Rect2(r.position+Vector2(493,30),Vector2(99,46)),false,count>0,18)

func _recruit():
 if selected<0:return
 text(battle.province(selected).name+"  /  新部队下回合行动，城市占用时在邻近地区部署",Vector2(174,207),19,MUTED)
 var kinds=["infantry","tank","artillery","fighter","destroyer",Rules.FACTIONS[battle.player].elite]
 for i in kinds.size():
  var kind: String=kinds[i]
  var data=Rules.TROOPS[kind]
  var r=Rect2(174+(i%3)*422,232+(i/3)*247,396,224)
  panel(r,Color("202d2d"),GOLD if i==5 else LINE)
  _portrait(kind,Rect2(r.position+Vector2(5,4),Vector2(144,125)))
  text(data.name,r.position+Vector2(148,42),23)
  text("专属军团" if i==5 else "常规军团",r.position+Vector2(148,76),16,GOLD if i==5 else MUTED)
  text("火力 %d  /  兵力 %d"%[data.attack,data.hp],r.position+Vector2(148,109),16,MUTED)
  var locked=(i==5 and int(battle.tech[battle.player].weapons)<2)
  text("需要武器科技 II" if locked else "%d 军费 · %d 工业"%[data.cost,data.steel],r.position+Vector2(18,153),18,GOLD)
  button("recruit:"+kind,"尚未解锁" if locked else "招募部署",Rect2(r.position+Vector2(18,172),Vector2(360,38)),not locked,not locked,18)
 text("战斗机需要航空科技；舰船需海军科技且只能在沿海部署。部署空间不足时无法招募。",Vector2(174,776),17,MUTED)

func _help():
 var entries=[
 ["真实地图与移动","拖动地图平移，双指或 + / − 缩放。点击军团，点击浅蓝圈地区移动。"],
 ["地区与海运","本版按战略地区移动。海港间有虚线航线，陆军沿航线自动运输；舰船只在沿海活动。"],
 ["八方征服","8 个势力分别控制领土、经济和军队。占领敌方首都会使其投降；控制全部首都获胜。"],
 ["科技与专属兵种","研究武器、装甲、后勤、工业、航空、海军。武器 II 解锁本势力专属军团。"],
 ["攻击与补给","红圈为可攻击敌人，远程单位拥有更大射程；城市补给恢复兵力，招募部队下回合行动。"],
 ["单机修改器","资源、无敌、无限行动、免费研究可分别开关，只对玩家生效，随存档保存。"],
 ["战役与存档","保住首都，在 80 回合内完成征服；每次行动后自动保存。真实地理上的架空战争设定。"]]
 for i in entries.size():
  text(entries[i][0],Vector2(174,215+i*76),23,GOLD)
  text(entries[i][1],Vector2(174,248+i*76),19,MUTED)

func _input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   if modal!="" and modal!="result":modal=""
   elif screen=="battle" and not busy:modal="pause"
  elif event.keycode==KEY_SPACE and screen=="battle" and modal=="" and not busy:_end_turn()
 if event is InputEventScreenTouch and event.pressed:
  pointer_time=clock
  _click(event.position)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and clock-pointer_time>0.3:
  _click(event.position)

func _click(at: Vector2):
 for i in range(buttons.size()-1,-1,-1):
  var b=buttons[i]
  if b.r.has_point(at):
   if b.active:_action(b.id)
   get_viewport().set_input_as_handled()
   return
 if modal!="":get_viewport().set_input_as_handled()

func _action(id: String):
 if id.begins_with("faction:"):
  faction=int(id.split(":")[1]);return
 if id.begins_with("research:"):
  var key=id.split(":")[1]
  _say("研究完成，部队与经济加成已生效" if battle.research(key) else "研究失败：资源不足或已满级")
  _save();return
 if id.begins_with("cheat:"):
  var key=id.split(":")[1]
  battle.set_cheat(key,not bool(battle.cheats[key]))
  _save();return
 if id.begins_with("recruit:"):
  var u=battle.recruit(selected,id.split(":")[1])
  if u.is_empty():_say("无法部署：请检查科技、资源、沿海条件和空地")
  else:
   modal="";_say("新军团已部署，下回合开始行动")
  _save();return
 if id.begins_with("focus:"):
  var side=int(id.split(":")[1])
  for p in battle.provinces:
   if int(p.owner)==side and p.capital:
    selected=int(p.id);unit_id=-1;world.focus(selected);modal="";return
 match id:
  "difficulty":difficulty=(difficulty+1)%3
  "new":
   if has_save:modal="replace"
   else:_new()
  "new_confirm":_new()
  "resume":_load()
  "close":modal=""
  "tech","factions","cheats","recruit","help","pause":modal=id
  "menu":
   _save();screen="menu";world.visible=false;modal=""
  "end":_end_turn()
  "repair":
   var u=battle.unit_by_id(unit_id)
   _say("补给完成" if not u.is_empty() and battle.repair(u) else "需我方驻地、受损部队和足够军费")
   _save()
  "zoom_in":world.zoom_by(1.3)
  "zoom_out":world.zoom_by(1/1.3)
  "overview","overview_close":
   world.zoom=1;world.camera=Vector2(0.5,0.5);modal=""

func _new():
 battle.setup(faction,difficulty)
 world.model=battle
 screen="battle";world.visible=true;modal="";busy=false
 for p in battle.provinces:
  if p.capital and int(p.owner)==battle.player:
   selected=int(p.id);break
 var u=battle.unit_at(selected)
 unit_id=int(u.id) if not u.is_empty() else -1
 world.zoom=4.4 if faction in [1,2,7,8] else 2.3
 world.focus(selected)
 _save()

func _select(id: int):
 if busy or battle.result!=0:return
 var u=battle.unit_by_id(unit_id)
 var target=battle.unit_at(id)
 if not u.is_empty() and int(u.side)==battle.player:
  if battle.can_attack(u,target):
   var hit=battle.attack(u,target)
   world.flashed=id;world.flash_time=1
   _say("造成 %d 伤害"%hit.get("damage",0))
   _save();_result();return
  if target.is_empty() and battle.move_unit(u,id):
   selected=id;_save();_result();return
 selected=id
 unit_id=int(target.id) if not target.is_empty() else -1

func _end_turn():
 if busy or battle.result!=0:return
 _save();busy=true;unit_id=-1
 for side in range(1,9):
  if side==battle.player or battle.result!=0:continue
  battle.begin_enemy(side)
  var ids=[]
  for u in battle.units:
   if int(u.side)==side:ids.append(int(u.id))
  for id in ids:
   if battle.result!=0:break
   battle.ai_step(id)
   await get_tree().create_timer(0.06).timeout
  battle.finish_enemy(side)
 battle.begin_player()
 busy=false
 _save();_result()
 if battle.result==0:_say("第 %d 回合，补给与科研已到账"%battle.turn)

func _result():
 if battle.result!=0:modal="result"

func _save():
 if screen!="battle" or busy:return
 var f=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
 if f==null:_say("存档失败：设备空间不足");return
 f.store_string(JSON.stringify(battle.snapshot()));f.close()
 if DirAccess.rename_absolute(SAVE+".tmp",SAVE)!=OK:_say("存档写入失败");return
 has_save=true

func _load():
 var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
 if not data is Dictionary or not battle.restore(data):_say("存档无法读取，请开始新战役");return
 world.model=battle;screen="battle";world.visible=true;modal="";unit_id=-1;selected=-1
 faction=battle.player
 for p in battle.provinces:
  if p.capital and int(p.owner)==battle.player:selected=int(p.id);break
 if selected>=0:world.focus(selected)
 _result()

func _say(s: String):
 notice=s;notice_time=3.4

func _notification(what):
 if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_WM_CLOSE_REQUEST:_save()
 if what==NOTIFICATION_WM_GO_BACK_REQUEST:
  if modal!="" and modal!="result":modal=""
  elif screen=="battle" and not busy:modal="pause"

func _ui_test():
 _new()
 assert(battle.player==faction)
 _action("cheat:resources")
 assert(battle.cheats.resources)
 _action("research:weapons")
 assert(battle.tech[battle.player].weapons==1)
 _save();_load()
 assert(battle.cheats.resources and battle.tech[battle.player].weapons==1)
 var previous=battle.turn
 await _end_turn()
 assert(battle.turn==previous+1 and not busy)
 _action("cheats");assert(modal=="cheats")
 _action("close");_action("menu");assert(screen=="menu")
 print("WORLD_UI_OK: faction selection, modifiers, research, save/resume, eight-faction round, menus")
 get_tree().quit()
