import os
import datetime
import render_modes

try :
  outputdir = os.environ['OUTPUT_DIR']
except KeyError :
  outputdir = '/app/map'

try :
  texturepath = os.environ['TEXTURE_PATH']
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
  world_dirs.extend(dirnames)
  break

worlds = { world_dir : os.path.abspath(world_dir) for world_dir in world_dirs }

for world_dir in world_dirs :
  config_dict = {
    'world_conf': {},
    'renders': {},
    'render_modes': []}
  try :
    assert os.file.exists(f'{world_dir}/renderer_config.json')
  except AssertionError :
    print('No config found in world "{world_dir}"')
    continue
  j = open(f'{world_dir}/renderer_config.json', r)
  blob = json.read()
  j.close()
  try :
    config_dict.update(json.loads(blob))
  except :
    print(f'Error parsing json in {world_dir}')
    continue
  try :
    config_dict['world_conf']['world_id']
  except KeyError :
    config_dict['world_conf']['world_id'] = world_dir
  render_generator = render_modes.rendermode_generator(config = config_dict)
  render_generator.generate_all_render_modes()
  modes.generate_all_render_configs()
  renders.update(modes.generated_render_config)

for r in renders.keys() :
  renders[r]['changelist'] = f'/home/bukkit/overviewer/changelists/{r}.changelist'
