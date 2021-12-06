import importlib.util
import os

world_name = os.environ['WORLD_NAME']
world_dir = os.environ['WORLD_DIR']
config_file = os.environ['CONFIG_FILE']

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

map_config_spec = importlib.util.spec_from_file_location("overviewer_config", config_file)
map_config = importlib.util.module_from_spec(map_config_spec)
map_config_spec.loader.exec_module(map_config)
print(dir(map_config))

global render_vars
render_vars = {
  'texturepath': texturepath,
  'changelist': changelist_file,
  'world': world_name
}
dev_vars = {
  'forcerender': True,
  'crop': (-100, -100, 100, 100)
}
if dev_mode :
  render_vars.update(dev_vars)
renders = {x: {**y, **render_vars} for x, y in map_config.renders.items()}
