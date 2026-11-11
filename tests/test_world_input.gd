extends SceneTree
var app
var checks=0

func _init():
 call_deferred("run")

func check(ok: bool,label: String):
 checks+=1
 if not ok:
  push_error("INPUT_FAIL: "+label)
  quit(1)
  assert(ok,label)

func frame():
 await process_frame
 await process_frame

func touch(at: Vector2,index: int=0,pressed: bool=true):
 var e=InputEventScreenTouch.new()
 e.index=index
 e.pressed=pressed
 e.position=at
 root.push_input(e,true)

func tap(at: Vector2):
 touch(at,0,true)
 await frame()
 touch(at,0,false)
 await frame()

func drag(at: Vector2,relative: Vector2,index: int=0):
 var e=InputEventScreenDrag.new()
 e.index=index
 e.position=at
 e.relative=relative
 root.push_input(e,true)

func mouse_tap(at: Vector2):
 var motion=InputEventMouseMotion.new()
 motion.position=at
 motion.global_position=at
 root.push_input(motion,true)
 await frame()
 for down in [true,false]:
  var e=InputEventMouseButton.new()
  e.position=at
  e.global_position=at
  e.button_index=MOUSE_BUTTON_LEFT
  e.pressed=down
  root.push_input(e,true)
  await frame()

func run():
 app=load("res://game/main.tscn").instantiate()
 root.add_child(app)
 await create_timer(0.15).timeout
 print("INPUT dimensions=",root.size," app=",app.size," buttons=",app.buttons.size())
 check(app.buttons.size()>8,"menu buttons rendered")
 await tap(Vector2(1348,494))
 check(app.faction==4,"touch selects USA faction")
 app.has_save=false
 await tap(Vector2(616,775))
 check(app.screen=="battle" and app.battle.player==4,"touch starts chosen faction")
 check(app.world.visible,"world map shown")
 # Pressing the UI zoom buttons routes through parent input and never selects map.
 var z: float=app.world.zoom
 await tap(Vector2(1104,168))
 check(app.world.zoom>z,"touch zoom button works")
 # Map gestures route through Control._gui_input, not the parent button dispatcher.
 var before: Vector2=app.world.camera
 touch(Vector2(570,420),0,true)
 drag(Vector2(655,460),Vector2(85,40))
 touch(Vector2(655,460),0,false)
 await frame()
 check(app.world.camera.distance_to(before)>0.001,"touch drag pans map")
 var z2: float=app.world.zoom
 touch(Vector2(450,400),0,true)
 touch(Vector2(650,400),1,true)
 drag(Vector2(660,400),Vector2(10,0),1)
 drag(Vector2(710,400),Vector2(50,0),1)
 touch(Vector2(450,400),0,false)
 touch(Vector2(710,400),1,false)
 await frame()
 check(app.world.zoom>z2,"pinch zoom changes scale")
 # Explicit province center after returning camera to player capital.
 var capital: int=app.battle.capitals[4]
 app.world.focus(capital)
 app.selected=-1
 app.unit_id=-1
 await frame()
 var pos: Vector2=app.world.point(app.battle.province(capital))+app.world.position
 await tap(pos)
 check(app.selected==capital and app.unit_id>=0,"touch selects actual province and unit")
 # Modal dispatch blocks map and only exposes overlay controls.
 await tap(Vector2(1208,66))
 check(app.modal=="cheats","modifier menu opened by touch")
 check(not app.world.enabled,"modal disables map input")
 var selected_before: int=app.selected
 await tap(Vector2(350,400))
 check(app.selected==selected_before and app.modal=="cheats","modal blocks underlying map")
 await tap(Vector2(1310,295))
 check(app.battle.cheats.resources,"touch toggles player resource modifier")
 await tap(Vector2(1362,133))
 check(app.modal=="","touch closes modal")
 await tap(Vector2(930,65))
 check(app.modal=="tech","touch opens technology")
 await tap(Vector2(370,412))
 check(app.battle.tech[4].weapons==1,"touch performs paid technology research")
 await tap(Vector2(1362,133))
 await tap(Vector2(1390,685))
 check(app.modal=="recruit","touch opens recruitment")
 await tap(Vector2(1362,133))
 # Mouse route in map, including wheel.
 await create_timer(0.35).timeout
 var wheel=InputEventMouseButton.new()
 wheel.position=Vector2(600,400)
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 wheel.pressed=true
 var old_zoom: float=app.world.zoom
 root.push_input(wheel,true)
 await frame()
 check(app.world.zoom<old_zoom,"mouse wheel reaches map")
 await mouse_tap(Vector2(930,65))
 check(app.modal=="tech","mouse click routes through parent toolbar")
 await mouse_tap(Vector2(1362,133))
 check(app.modal=="","mouse closes modal")
 var target=-1
 for p in app.battle.provinces:
  if int(p.owner)==4 and int(p.id)!=capital:
   target=int(p.id)
   break
 app.world.focus(target)
 app.unit_id=-1
 await frame()
 await mouse_tap(app.world.point(app.battle.province(target))+app.world.position)
 check(app.selected==target,"mouse click selects actual province")
 # Free one local garrison slot to exercise the actual recruitment button.
 var existing=app.battle.unit_at(target)
 if not existing.is_empty():app.battle.units.erase(existing)
 app.unit_id=-1
 await frame()
 await tap(Vector2(1390,573))
 check(app.modal=="recruit","empty owned region recruits through sidebar")
 var troops_before=app.battle.units.size()
 await tap(Vector2(360,423))
 check(app.battle.units.size()==troops_before+1 and app.modal=="","recruit button deploys and closes dialog")
 app._save()
 check(FileAccess.file_exists(app.SAVE),"input actions persist a save")
 print("WORLD_INPUT_OK: %d real routed touch/mouse checks"%checks)
 quit(0)
