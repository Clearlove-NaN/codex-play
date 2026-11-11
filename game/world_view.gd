extends Control
signal province_clicked(id)
const FONT = preload("res://assets/fonts/Chinese.ttc")
var model
var selected = -1
var selected_unit = -1
var zoom = 2.4
var camera = Vector2(0.53,0.28)
var map_texture: Texture2D
var atlas: Texture2D
var elite_atlas: Texture2D
const ELITES=["commando","tiger","guards","sherman","volunteer","zero","legion","bersaglieri"]
var atlas_columns = 4
var atlas_rows = 2
var geometry: Array = []
var sea_edges: Array = []
var dragging = false
var drag_length = 0.0
var touches = {}
var pinch_distance = 0.0
var routes = true
var enabled = true
var draw_reachable = {}
var cache_key = ""
var flashed = -1
var flash_time = 0.0

func _ready():
 clip_contents = true
 mouse_filter = Control.MOUSE_FILTER_STOP
 if ResourceLoader.exists("res://assets/world/map.png"): map_texture = load("res://assets/world/map.png")
 if ResourceLoader.exists("res://assets/art/units.png"): atlas = load("res://assets/art/units.png")
 if ResourceLoader.exists("res://assets/art/elites.png"): elite_atlas=load("res://assets/art/elites.png")
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world.json"))
 if data is Dictionary:
  geometry = data.get("countries",[])
  for edge in data.get("sea_edges",[]): sea_edges.append([int(edge[0]),int(edge[1])])

func _process(delta):
 flash_time = maxf(0,flash_time-delta)
 queue_redraw()

func normalized(p: Dictionary) -> Vector2:
 return Vector2((float(p.lon)+180)/360,(85-float(p.lat))/145)

func point(p: Dictionary) -> Vector2:
 return (normalized(p)-camera)*size*zoom+size/2

func focus(id: int):
 if model == null: return
 camera = normalized(model.province(id))
 constrain()

func constrain():
 var edge = Vector2.ONE/(2*zoom)
 camera = camera.clamp(edge,Vector2.ONE-edge)

func zoom_by(factor: float):
 zoom = clampf(zoom*factor,1,5)
 constrain()
 queue_redraw()

func color(side: int) -> Color:
 if side == 0: return Color("a9ac97")
 return Color(model.FACTIONS[side].color)

func _draw():
 if model == null: return
 draw_rect(Rect2(Vector2.ZERO,size),Color("233d49"))
 if map_texture:
  var src = Rect2((camera-Vector2.ONE/(2*zoom))*map_texture.get_size(),map_texture.get_size()/zoom)
  draw_texture_rect_region(map_texture,Rect2(Vector2.ZERO,size),src)
 # Sovereign outlines from Natural Earth retain the real geography under faction washes.
 for country in geometry:
  var side=int(country.get("owner",0))
  if side==0:continue
  if model.capitals.has(side):side=int(model.province(int(model.capitals[side])).owner)
  for ring in country.polygons:
   var pts=PackedVector2Array()
   for ll in ring:pts.append(point({"lon":ll[0],"lat":ll[1]}))
   if pts.size()>3:
    draw_colored_polygon(pts,Color(color(side),0.11))
    draw_polyline(pts,Color(color(side),0.36),1.1,true)
 # Thin latitude/longitude graticule, with subdued cartographic ink.
 for lon in range(-180,181,30):
  var x = ((lon+180.0)/360-camera.x)*size.x*zoom+size.x/2
  draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.76,0.86,0.8,0.07),1)
 for lat in range(-60,86,15):
  var y = ((85-lat)/145.0-camera.y)*size.y*zoom+size.y/2
  draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.76,0.86,0.8,0.07),1)
 # Routes are navigable province links, including explicitly defined sea passages.
 var selected_data = model.unit_by_id(selected_unit)
 var key = str(selected_unit)+str(model.turn)+str(model.phase)+str(model.units)+str(model.cheats)+str(model.tech)
 if key != cache_key:
  cache_key = key
  draw_reachable = model.reachable(selected_data) if not selected_data.is_empty() and int(selected_data.side)==model.player else {}
 if routes:
  for p in model.provinces:
   var a = point(p)
   for n in p.neighbors:
    if int(n) <= int(p.id): continue
    var b = point(model.province(int(n)))
    # Date-line links are shown as short edge exits, not across the entire globe.
    if absf(a.x-b.x)>size.x*zoom*0.5: continue
    var sea = [int(p.id),int(n)] in sea_edges or [int(n),int(p.id)] in sea_edges
    var col = Color(0.55,0.78,0.88,0.20) if sea else Color(0.9,0.83,0.6,0.19)
    if selected==int(p.id) or selected==int(n): col = Color("d6c48c")
    draw_dashed_line(a,b,col,1.4 if zoom>2 else 1,10 if sea else 5,true)
 for p in model.provinces:
  var v = point(p)
  if not Rect2(-80,-80,size.x+160,size.y+160).has_point(v): continue
  var col = color(int(p.owner))
  draw_circle(v,21 if p.capital else 14,Color(col,0.14))
  if p.capital: draw_arc(v,24,0,TAU,30,Color(col,0.48),1.5,true)
  draw_circle(v+Vector2(1,2),7,Color(0,0,0,0.5))
  draw_circle(v,5.5,col)
  draw_arc(v,8,0,TAU,20,Color("e6dcc0"),1,true)
  if draw_reachable.has(int(p.id)) and enabled:
   draw_arc(v,16,0,TAU,32,Color("abe7de"),2,true)
  if int(p.id)==selected:
   draw_arc(v,29,0,TAU,44,Color("efd098"),2.5,true)
  if (zoom>=1.6 or p.capital or int(p.id)==selected):
   var text: String = p.name
   var width = FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
   draw_rect(Rect2(v.x-width/2-5,v.y+21,width+10,23),Color(0.035,0.07,0.08,0.8))
   draw_string(FONT,v+Vector2(-width/2,38),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f0e7cd"))
 for u in model.units:
  var v = point(model.province(int(u.province)))
  if not Rect2(-70,-70,size.x+140,size.y+140).has_point(v): continue
  var col = color(int(u.side))
  draw_formation(v+Vector2(0,-17),u,col)
  if not selected_data.is_empty() and model.can_attack(selected_data,u) and enabled:
   draw_arc(v,33,0,TAU,40,Color("ec947e"),2.5,true)
  if int(u.province)==flashed and flash_time>0:
   draw_arc(v,35+(1-flash_time)*40,0,TAU,40,Color(1,0.65,0.3,flash_time),3,true)
 draw_rect(Rect2(0,0,size.x,size.y),Color("718178"),false,1)
 draw_rect(Rect2(10,8,327,34),Color(0.025,0.06,0.08,0.82))
 draw_rect(Rect2(10,size.y-40,520,31),Color(0.025,0.06,0.08,0.72))
 draw_string(FONT,Vector2(18,30),"世界征服 / 1940 · 架空推演",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e1dcc5"))
 draw_string(FONT,Vector2(18,size.y-17),"拖动平移  ·  双指 / 滚轮缩放  ·  浅蓝圈移动  ·  红圈攻击",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d2d8cc"))

func sprite_index(kind: String) -> int:
 if kind in ["tank","sherman"]: return 1
 if kind in ["artillery","guards"]: return 2
 if kind in ["fighter","zero"]: return 3
 if kind=="destroyer": return 4
 if kind=="tiger": return 5
 if kind in ["commando","legion","volunteer","bersaglieri"]: return 6
 return 0

func draw_formation(v: Vector2,u: Dictionary,col: Color):
 var width = 58.0 if zoom>1.5 else 36.0
 draw_ellipse_shadow(v+Vector2(0,10),Vector2(width*0.42,8))
 if atlas:
  var texture = elite_atlas if u.kind in ELITES and elite_atlas else atlas
  var index = ELITES.find(u.kind) if u.kind in ELITES else sprite_index(u.kind)
  var cell_size = texture.get_size()/Vector2(atlas_columns,atlas_rows)
  var src = Rect2(Vector2(index%atlas_columns,index/atlas_columns)*cell_size,cell_size)
  draw_texture_rect_region(texture,Rect2(v-Vector2(width/2,width*0.60),Vector2(width,width)),src)
 else:
  draw_rect(Rect2(v-Vector2(18,12),Vector2(36,24)),col.darkened(0.45))
  var label = {"infantry":"步","tank":"坦","artillery":"炮","fighter":"空","destroyer":"舰"}.get(u.kind,"特")
  draw_string(FONT,v+Vector2(-8,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,col)
 var stats = model.unit_stats(u)
 var ratio = clampf(float(u.hp)/float(stats.hp),0,1)
 draw_rect(Rect2(v+Vector2(-23,17),Vector2(46,5)),Color("192327"))
 draw_rect(Rect2(v+Vector2(-23,17),Vector2(46*ratio,5)),col)
 draw_rect(Rect2(v+Vector2(-32,-28),Vector2(16,11)),col)
 if int(u.side)==model.player and not u.acted: draw_circle(v+Vector2(25,-20),3.5,Color("fff0c2"))

func draw_ellipse_shadow(v: Vector2,radius: Vector2):
 var pts = PackedVector2Array()
 for i in 24: pts.append(v+Vector2(cos(TAU*i/24),sin(TAU*i/24))*radius)
 draw_colored_polygon(pts,Color(0.02,0.03,0.02,0.4))

func choose(at: Vector2):
 var best = -1
 var nearest = 35.0
 for p in model.provinces:
  var d = point(p).distance_to(at)
  if d<nearest:
   best = int(p.id)
   nearest = d
 if best>=0: province_clicked.emit(best)

func _gui_input(event):
 if not enabled: return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(1.2)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1/1.2)
  elif event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    dragging = true
    drag_length = 0
   else:
    if dragging and drag_length<9: choose(event.position)
    dragging = false
 elif event is InputEventMouseMotion and dragging:
  camera -= event.relative/(size*zoom)
  drag_length += event.relative.length()
  constrain()
 elif event is InputEventScreenTouch:
  if event.pressed:
   touches[event.index]=event.position
   if touches.size()==1: drag_length=0
  else:
   if touches.size()==1 and drag_length<12: choose(event.position)
   touches.erase(event.index)
   pinch_distance = 0
 elif event is InputEventScreenDrag:
  touches[event.index]=event.position
  if touches.size()==1:
   camera-=event.relative/(size*zoom)
   drag_length+=event.relative.length()
   constrain()
  elif touches.size()==2:
   var pts = touches.values()
   var d: float = pts[0].distance_to(pts[1])
   if pinch_distance>0: zoom_by(d/pinch_distance)
   pinch_distance=d
   drag_length=100
 accept_event()
