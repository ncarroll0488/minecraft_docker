import importlib.util
import os

world_name = os.environ['WORLD_NAME']
world_dir = os.environ['WORLD_DIR']

dev_mode = False
try :
  os.environ['DEV_MODE']
  dev_mode = True
except KeyError :
  pass

try :
  outputdir = os.environ['OUTPUT_DIR']
except KeyError :
  outputdir = '/app/workspace/map'

try :
  texturepath = os.environ['TEXTURE_DIR']
except KeyError :
  texturepath = '/app/workspace/textures/default/'

try :
  changelist_dir = os.environ['CHANGELIST_DIR']
except KeyError :
  changelist_dir = '/app/workspace/changelists'

changelist_file = f'{changelist_dir}/changelist.txt'

worlds = {
  world_name: f'{world_dir}'
}

'''
dev_vars = {
  'forcerender': True,
  'crop': (-100, -100, 100, 100)
}
if dev_mode :
  render_vars.update(dev_vars)
'''

cave_lit = [Base(), EdgeLines(), Cave(only_lit=True), DepthTinting()]

def auto_poi_signs(poi):
  if (poi['id'] in ['Sign', 'minecraft:sign']) and poi['Text1'] == '$$POI$$' :
    return(" ".join([poi['Text2'], poi['Text3'], poi['Text4']]))

def playerIcons(poi):
  if poi['id'] == 'Player':
    poi['icon'] = "https://overviewer.org/avatar/%s" % poi['EntityId']
    return "Last known location for %s" % poi['EntityId']

default_markers = [
  {
    'name': "POIs",
    'filterFunction': auto_poi_signs
  },
  {
    'name': "Players",
    'filterFunction': playerIcons,
    'checked': False
  }
]

renders = {
  'Caves': {
    'world': world_name,
    'dimension': 'overworld',
    'rendermode': cave_lit,
    'title': 'Caves',
    'markers': default_markers
  },
  'Caves_SW': {
    'world': world_name,
    'dimension': 'overworld',
    'northdirection': 'lower-right',
    'rendermode': cave_lit,
    'title': 'Caves SW',
    'markers': default_markers
  },
  'Day': {
    'world': world_name,
    'dimension': 'overworld',
    'rendermode': 'smooth_lighting',
    'title': 'Day',
    'markers': default_markers
  },
  'Day_SW': {
    'world': world_name,
    'dimension': 'overworld',
    'northdirection': 'lower-right',
    'rendermode': 'smooth_lighting',
    'title': 'Day SW',
    'markers': default_markers
  },
  'Night': {
    'world': world_name,
    'dimension': 'overworld',
    'rendermode': 'smooth_night',
    'title': 'Night',
    'markers': default_markers
  },
  'Night_SW': {
    'world': world_name,
    'dimension': 'overworld',
    'northdirection': 'lower-right',
    'rendermode': 'smooth_night',
    'title': 'Night SW',
    'markers': default_markers
  }
}

'''
  },
  "Biome_Overlay": {
    'world': world_name,
    'dimension': 'overworld',
    'rendermode': [ClearBase(), BiomeOverlay()],
    'title': "Biome Coloring Overlay NE",
    'overlay': ['Day', 'Night']
  },
  "Biome_Overlay_SW": {
    'world': world_name,
    'dimension': 'overworld',
    'northdirection': 'lower-right',
    'rendermode': [ClearBase(), BiomeOverlay()],
    'title': "Biome Coloring Overlay SW",
    'overlay': ['Day_SW', 'Night_SW']
  }
'''
