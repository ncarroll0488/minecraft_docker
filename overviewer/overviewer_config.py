import os
import datetime
import render_modes
import json

try :
  outputdir = os.environ['OUTPUT_DIR']
except KeyError :
  outputdir = '/app/map'

try :
  texturepath = os.environ['TEXTURE_DIR']
except KeyError :
  texturepath = '/app/textures'

try :
  worlds_basedir = os.environ['DATA_SOURCE']
except KeyError :
  worlds_basedir = '/app/worlds'

renders = {}
world_dirs = []
worlds = {}
for (dirpath, dirnames, filenames) in os.walk(worlds_basedir):
  for d in dirnames :
    world_dirs.append(f'{worlds_basedir}/{d}')
  break

for world_dir in world_dirs :
  world_abs_dir = os.path.abspath(f'{world_dir}')
  worlds.update({world_dir : f'{world_abs_dir}/world'})
  conf_file = f'{world_abs_dir}/overviewer_config.json'
  config_dict = {
    'world_conf': {},
    'renders': {},
    'render_modes': []}
  try :
    assert os.path.exists(conf_file)
  except AssertionError :
    print(f'No config found in world "{conf_file}"')
    continue
  j = open(conf_file, 'r')
  blob = json.loads(j.read())
  j.close()
  try :
    config_dict.update(blob)
  except Exception as e:
    print(f'Error parsing json in {world_dir}: {e}')
    continue
  try :
    config_dict['world_conf']['world_id']
  except KeyError :
    config_dict['world_conf']['world_id'] = world_dir
  render_generator = render_modes.rendermode_generator(config = config_dict)
  render_generator.generate_all_render_modes()
  render_generator.generate_all_render_configs()
  renders.update(render_generator.generated_render_config)

for r in renders.keys() :
  renders[r]['changelist'] = f'/home/bukkit/overviewer/changelists/{r}.changelist'
