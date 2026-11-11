#!/usr/bin/env python3
"""Build geographic campaign data and a real-world cartographic raster.
Natural Earth country data is public domain. Terrain uses Blue Marble world
texture distributed in the MIT-licensed three-globe example collection.
"""
import json, math, urllib.request, os
os.environ.setdefault("MPLCONFIGDIR", "/tmp/iron-meridian-matplotlib")
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/world'; OUT.mkdir(parents=True,exist_ok=True)
# name, lon, lat, faction, capital, coastal, terrain
raw=[
 ('伦敦',-0.12,51.5,1,1,1,'plain'),('格拉斯哥',-4.25,55.86,1,0,1,'forest'),('亚历山大',29.92,31.2,1,0,1,'desert'),('德里',77.2,28.6,1,0,0,'plain'),('新加坡',103.82,1.35,1,0,1,'forest'),
 ('柏林',13.4,52.52,2,1,0,'plain'),('汉堡',9.99,53.55,2,0,1,'plain'),('慕尼黑',11.58,48.14,2,0,0,'mountain'),
 ('莫斯科',37.62,55.75,3,1,0,'forest'),('列宁格勒',30.3,59.93,3,0,1,'forest'),('基辅',30.52,50.45,3,0,0,'plain'),('伏尔加格勒',44.5,48.7,3,0,0,'plain'),('新西伯利亚',82.92,55.03,3,0,0,'forest'),('海参崴',131.88,43.12,3,0,1,'forest'),
 ('华盛顿',-77.04,38.9,4,1,1,'plain'),('纽约',-74.01,40.71,4,0,1,'plain'),('芝加哥',-87.63,41.88,4,0,0,'plain'),('旧金山',-122.42,37.77,4,0,1,'plain'),('洛杉矶',-118.24,34.05,4,0,1,'desert'),('安克雷奇',-149.9,61.22,4,0,1,'mountain'),('檀香山',-157.86,21.3,4,0,1,'plain'),
 ('北京',116.4,39.9,5,1,0,'plain'),('上海',121.47,31.23,5,0,1,'plain'),('重庆',106.55,29.56,5,0,0,'mountain'),('乌鲁木齐',87.62,43.83,5,0,0,'desert'),('广州',113.26,23.13,5,0,1,'forest'),
 ('东京',139.69,35.69,6,1,1,'plain'),('大阪',135.5,34.69,6,0,1,'plain'),('札幌',141.35,43.06,6,0,1,'forest'),
 ('巴黎',2.35,48.86,7,1,0,'plain'),('马赛',5.37,43.3,7,0,1,'plain'),('阿尔及尔',3.05,36.75,7,0,1,'desert'),
 ('罗马',12.49,41.9,8,1,1,'plain'),('米兰',9.19,45.46,8,0,0,'mountain'),('的黎波里',13.2,32.88,8,0,1,'desert'),
 ('马德里',-3.7,40.42,0,0,0,'plain'),('里斯本',-9.14,38.72,0,0,1,'plain'),('奥斯陆',10.75,59.91,0,0,1,'forest'),('斯德哥尔摩',18.07,59.33,0,0,1,'forest'),('华沙',21.01,52.23,0,0,0,'plain'),('伊斯坦布尔',28.98,41.01,0,0,1,'plain'),('雅典',23.73,37.98,0,0,1,'plain'),('布加勒斯特',26.1,44.43,0,0,0,'plain'),
 ('德黑兰',51.39,35.69,0,0,0,'mountain'),('巴格达',44.37,33.32,0,0,0,'desert'),('卡拉奇',67.01,24.86,0,0,1,'desert'),('孟买',72.88,19.08,0,0,1,'plain'),('曼谷',100.5,13.75,0,0,1,'forest'),('首尔',126.98,37.57,0,0,1,'mountain'),('雅加达',106.85,-6.21,0,0,1,'forest'),('悉尼',151.21,-33.87,0,0,1,'plain'),('珀斯',115.86,-31.95,0,0,1,'desert'),
 ('卡萨布兰卡',-7.59,33.57,0,0,1,'desert'),('开普敦',18.42,-33.93,0,0,1,'plain'),('内罗毕',36.82,-1.29,0,0,0,'plain'),('达喀尔',-17.45,14.72,0,0,1,'desert'),('拉各斯',3.38,6.52,0,0,1,'forest'),
 ('墨西哥城',-99.13,19.43,0,0,0,'mountain'),('巴拿马',-79.52,8.98,0,0,1,'forest'),('波哥大',-74.07,4.71,0,0,0,'mountain'),('利马',-77.04,-12.05,0,0,1,'desert'),('里约热内卢',-43.17,-22.91,0,0,1,'forest'),('布宜诺斯艾利斯',-58.38,-34.6,0,0,1,'plain'),('圣地亚哥',-70.67,-33.45,0,0,1,'mountain'),('温哥华',-123.12,49.28,0,0,1,'forest'),('蒙特利尔',-73.57,45.5,0,0,1,'forest'),('雷克雅未克',-21.94,64.15,0,0,1,'plain'),('乌兰巴托',106.92,47.92,0,0,0,'plain')]
provinces=[dict(id=i,name=n,lon=x,lat=y,owner=o,capital=bool(cap),coastal=bool(coast),terrain=t,neighbors=[]) for i,(n,x,y,o,cap,coast,t) in enumerate(raw)]
lookup={p['name']:p['id'] for p in provinces}
sea=[]
def link(a,b,naval=False):
 i,j=lookup[a],lookup[b]
 if j not in provinces[i]['neighbors']:provinces[i]['neighbors'].append(j);provinces[j]['neighbors'].append(i)
 if naval:
  assert provinces[i]['coastal'] and provinces[j]['coastal'],(a,b)
  edge=sorted([i,j])
  if edge not in sea:sea.append(edge)
def chain(names,naval=False):
 for a,b in zip(names,names[1:]):link(a,b,naval)
chain(['格拉斯哥','伦敦'])
chain(['里斯本','马德里','巴黎','汉堡','柏林','华沙','基辅','莫斯科','新西伯利亚','乌兰巴托','北京','海参崴'])
chain(['巴黎','马赛','米兰','慕尼黑','柏林'])
chain(['汉堡','慕尼黑','米兰','罗马'])
chain(['莫斯科','列宁格勒'])
chain(['列宁格勒','斯德哥尔摩','奥斯陆'])
chain(['基辅','伏尔加格勒','德黑兰','乌鲁木齐','新西伯利亚'])
chain(['华沙','布加勒斯特','雅典'])
chain(['布加勒斯特','伊斯坦布尔','巴格达','德黑兰'])
chain(['巴格达','亚历山大','的黎波里','阿尔及尔','卡萨布兰卡','达喀尔','拉各斯','内罗毕','开普敦'])
chain(['德黑兰','卡拉奇','德里','孟买'])
chain(['乌鲁木齐','德里']);chain(['乌鲁木齐','重庆','北京','上海','广州','重庆'])
chain(['重庆','曼谷']);chain(['广州','曼谷','新加坡'])
chain(['海参崴','首尔']);chain(['北京','首尔'])
chain(['札幌','东京','大阪'])
chain(['安克雷奇','温哥华','旧金山','洛杉矶','墨西哥城','巴拿马','波哥大','利马','圣地亚哥','布宜诺斯艾利斯','里约热内卢'])
chain(['温哥华','芝加哥','蒙特利尔','纽约','华盛顿','芝加哥'])
link('芝加哥','洛杉矶');link('芝加哥','墨西哥城');link('里约热内卢','波哥大')
link('悉尼','珀斯')
for a,b in [('伦敦','汉堡'),('伦敦','里斯本'),('格拉斯哥','奥斯陆'),('格拉斯哥','雷克雅未克'),('雷克雅未克','蒙特利尔'),('伦敦','纽约'),('里斯本','纽约'),('马赛','阿尔及尔'),('罗马','的黎波里'),('罗马','雅典'),('雅典','亚历山大'),('里斯本','卡萨布兰卡'),('孟买','亚历山大'),('孟买','新加坡'),('新加坡','雅加达'),('雅加达','珀斯'),('雅加达','悉尼'),('悉尼','檀香山'),('檀香山','旧金山'),('檀香山','东京'),('札幌','安克雷奇'),('札幌','海参崴'),('列宁格勒','斯德哥尔摩'),('札幌','东京'),('大阪','首尔'),('大阪','上海'),('上海','新加坡'),('里约热内卢','拉各斯'),('布宜诺斯艾利斯','开普敦')]:link(a,b,True)
for p in provinces:p['neighbors'].sort()
# Graph invariants: no self edges, symmetric routes, playable start for all sides.
seen={0};todo=[0]
while todo:
 for j in provinces[todo.pop()]['neighbors']:
  if j not in seen:seen.add(j);todo.append(j)
assert len(seen)==len(provinces)
for p in provinces:
 assert p['id'] not in p['neighbors']
 assert all(p['id'] in provinces[i]['neighbors'] for i in p['neighbors'])
for side in range(1,9):
 assert sum(p['owner']==side for p in provinces)>=3
 assert sum(p['owner']==side and p['capital'] for p in provinces)==1
world=dict(version=2,bounds=[-180,85,180,-60],projection='equirectangular',width=2560,height=1280,provinces=provinces,sea_edges=sea,countries=[])
geo=json.loads((OUT/'countries.geojson').read_text())
country_factions={'United Kingdom':1,'Germany':2,'Russia':3,'United States of America':4,'China':5,'Japan':6,'France':7,'Italy':8}
for feature in geo['features']:
 props=feature['properties']; geom=feature['geometry']; coords=geom['coordinates']
 rings=[poly[0] for poly in coords] if geom['type']=='MultiPolygon' else [coords[0]]
 rings=[[[round(x,3),round(y,3)] for x,y in ring] for ring in rings]
 world['countries'].append(dict(name=props['NAME_ZH'],english=props['ADMIN'],owner=country_factions.get(props['ADMIN'],0),polygons=rings))
(OUT/'world.json').write_text(json.dumps(world,ensure_ascii=False,separators=(',',':')))
print(f'Wrote {len(provinces)} provinces, {sum(len(p["neighbors"]) for p in provinces)//2} routes ({len(sea)} sea), {len(world["countries"])} countries')
# Raster is optional when re-running only data generation.
if '--data-only' not in __import__('sys').argv:
 import matplotlib;matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 from matplotlib.patches import Polygon
 from PIL import Image
 source=OUT/'earth-blue-marble.jpg'
 if not source.exists():urllib.request.urlretrieve('https://raw.githubusercontent.com/vasturiano/three-globe/master/example/img/earth-blue-marble.jpg',source)
 fig=plt.figure(figsize=(25.6,12.8),dpi=100,facecolor='#112937');ax=fig.add_axes([0,0,1,1])
 ax.imshow(Image.open(source),extent=(-180,180,-90,90),origin='upper',aspect='auto',interpolation='lanczos')
 # Subtle cartographic wash makes units/ownership readable while retaining relief.
 for c in world['countries']:
  if c['english']=='Antarctica':continue
  for ring in c['polygons']:
   ax.add_patch(Polygon(ring,closed=True,facecolor=(0.69,0.68,0.46,0.12),edgecolor=(0.84,0.85,0.66,0.30),linewidth=0.44))
 for lon in range(-180,181,30):ax.plot([lon,lon],[-60,85],color=(0.75,0.84,0.78,0.10),lw=.5)
 for lat in range(-60,86,30):ax.plot([-180,180],[lat,lat],color=(0.75,0.84,0.78,0.10),lw=.5)
 ax.set_xlim(-180,180);ax.set_ylim(-60,85);ax.set_axis_off()
 fig.savefig(OUT/'map.png',dpi=100,facecolor=fig.get_facecolor());plt.close(fig)
 print('Wrote map.png 2560×1280, bounds[-180,85,180,-60]')
