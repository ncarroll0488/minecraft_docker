from overviewer_core import rendermodes as rmodes
import datetime
import json
import os

class rendermode_generator() :
  def __init__(self, config_json = '{}', config = {}) :
    self.render_mode_definitions = {}
    self.generated_render_config = {}
    self.__render_config = json.loads(config_json)
    self.__render_config.update(config)
    self.__day_of_month = datetime.datetime.now().day

    try :
      assert self.__render_config['world_conf']['northdirections'] != []
    except (AssertionError, KeyError) :
      self.__render_config['world_conf']['northdirections'] = ['upper-left']

    try :
      assert self.__render_config['world_conf']['title_fmt_string'] != ""
    except (AssertionError, KeyError) :
      self.__render_config['world_conf']['title_fmt_string'] = '{world_id} {dimension} {config_title} {northdirection}'

    try :
      type(self.__render_config['world_conf']['forcerender_day']) == int
    except (AssertionError, KeyError) :
      self.__render_config['world_conf']['forcerender_day'] = 0

    try :
      type(self.__render_config['world_conf']['dimensions']) != []
    except (AssertionError, KeyError) :
      self.__render_config['world_conf']['dimensions'] = ['overworld']

  def generate_all_render_configs(self) :
    renders = {}
    world_id = self.__render_config['world_conf']['world_id']

    for config_title, conf_dict in self.__render_config['renders'].items() :

      # If we can, grab dimension config locally rather than gloally
      try :
        dimensions_to_render = conf_dict['dimensions']
      except KeyError :
        dimensions_to_render = self.__render_config['world_conf']['dimensions']

      # Do the same for north directions
      try :
        north_directions = conf_dict['northdirections']
      except KeyError :
        north_directions = self.__render_config['world_conf']['northdirections']

      try :
        title_fmt_string = conf_dict['title_fmt_string']
      except KeyError :
        title_fmt_string = self.__render_config['world_conf']['title_fmt_string']

      # Generate confs
      for render_mode in conf_dict['rendermodes'] :
        for direction in north_directions :
          for dimension in dimensions_to_render :
            render_id = f'{world_id}_{dimension}_{config_title}_{direction}'
            try :
              title = conf_dict['Title']
            except KeyError :
              title = title_fmt_string.format(
                world_id = world_id,
                dimension = dimension,
                config_title = config_title,
                northdirection = direction)
            renders[render_id] = {
              'world': world_id,
              'title': title,
              'rendermode': self.get_render_mode(render_mode),
              'dimension': dimension,
              'northdirection': direction,
              'forcerender': (self.__day_of_month == self.__render_config['world_conf']['forcerender_day']) }
    self.generated_render_config.update(renders)

  def get_render_mode(self, name) :
    # First search the object's dict of render modes
    try :
      mode = self.render_mode_definitions['name']
    except KeyError :
      # Then, assume it's in the provider's built-in modes.
      mode = getattr(rmodes, name)
    return(mode)

  def generate_all_render_modes(self) :
    self.render_mode_definitions.update({ render_mode_name: self.__generate_render_mode_definition(**render_mode_conf) for render_mode_name, render_mode_conf in self.__render_config['render_modes'] })

  def __generate_render_mode_definition(self, render_mode_name, render_mode_method, render_mode_args) :
    try :
      render_mode = self.render_mode_definitions[render_mode_name]
    except AttributeError :
      render_mode_method = getattr(rmodes, render_mode_name)
      if callable(render_mode_method) :
        render_mode = render_mode_method(**render_mode_args)
      else :
        render_mode = render_mode_method
    return(render_mode)
'''
try :
  block_id_lower, block_id_upper = [ int(a) for a in os.environ['BLOCK_ID_RANGE'].split(',') ]
except KeyError :
  block_id_lower, block_id_upper = [1,32767]

try :
  rail_block_ids = [ int(a) for a in os.environ['RAIL_BLOCK_IDS'].split(',') ]
except KeyError :
  # Rails, powered rails, detector rails
  rail_block_ids = [27, 28, 66]

try :
  ice_block_ids = [ int(a) for a in os.environ['ICE_BLOCK_IDS'].split(',') ]
except KeyError :
  # Ice, packed ice
  ice_block_ids = [78, 79]

try :
  water_block_ids = [ int(a) for a in os.environ['WATER_BLOCK_IDS'].split(',') ]
except KeyError :
  # Water, flowing water
  water_block_ids = [8, 9]

try :
  valuable_block_ids = [ int(a) for a in os.environ['valuable_block_ids'].split(',') ]
except KeyError :
  valuable_block_ids = [
    14,         # Gold Ore
    15,         # Iron Ore
    16,         # Coal Ore
    21,         # Lapis Ore
    56,         # Diamond Ore
    73,         # Redstone Ore
    129,        # Emerald Ore
    22,         # Lapis Block
    41,         # Gold Block
    42,         # Iron Block
    57,         # Diamond Block
    133,        # Emerald Block
    152,        # Redstone Block
    173         # Coal Block
  ]

# Generate a list of all likely minecraft block IDs.
all_block_ids = range(block_id_lower, block_id_higher)

# Create a list of all blocks and remove the block IDs of water from them
nowater = list(set(all_block_ids) - set(water_block_ids))

# Create a list of all blocks and remove the block IDs of rails from them
norails = list(set(all_block_ids) - set(rail_block_ids))

# Create a list of all blocks and remove the block IDs of valuable resources
no_valuables = list(set(all_block_ids) - set(valuable_block_ids))

'''
