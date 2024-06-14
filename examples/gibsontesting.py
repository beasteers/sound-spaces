import os
os.environ['HABITAT_SIM_LOG'] = 'sensor=VeryVerbose'
# os.environ['HABITAT_SIM_LOG'] = 'sim=VeryVerbose:scene=VeryVerbose'
# os.environ['HABITAT_SIM_LOG'] = 'sim=Debug:scene=Debug'
# os.chdir('/sound-spaces')

# /habitat-sim/tools/gen_gibson_semantics.sh /sound-spaces/data/scene_datasets/gibson_data/gibson/automated_graph /sound-spaces/data/scene_datasets/gibson_data/gibson /sound-spaces/data/scene_datasets/gibson_data/gibson-out



import os
import quaternion
import habitat_sim.sim
import numpy as np
from scipy.io import wavfile


from pprint import pprint
def try_getattr(o,k):
    try:
        return getattr(o,k)
    except TypeError:
        return 
def get_obj_data(o):
    return {k: try_getattr(o, k) for k in dir(o) if not k.startswith('__') and not callable(try_getattr(o, k))}



def get_sim(scene_id, navmesh, scene_config):
    print(os.path.abspath(scene_id), os.path.isfile(scene_id))
    print(os.path.abspath(navmesh), os.path.isfile(navmesh))
    print(os.path.abspath(scene_config), os.path.isfile(scene_config))
    backend_cfg = habitat_sim.SimulatorConfiguration()
    backend_cfg.scene_id = scene_id
    # IMPORTANT: missing this file will lead to load the semantic scene incorrectly
    backend_cfg.scene_dataset_config_file = scene_config
    backend_cfg.load_semantic_mesh = True
    backend_cfg.enable_physics = False
    agent_config = habitat_sim.AgentConfiguration()
    cfg = habitat_sim.Configuration(backend_cfg, [agent_config])
    sim = habitat_sim.Simulator(cfg)
    sim.pathfinder.load_nav_mesh(navmesh)
    return sim

def add_audio_sensor(sim, position, material_config="data/mp3d_material_config.json"):
    audio_sensor_spec = habitat_sim.AudioSensorSpec()
    audio_sensor_spec.uuid = "audio_sensor"
    audio_sensor_spec.enableMaterials = True
    audio_sensor_spec.channelLayout.channelType = habitat_sim.sensor.RLRAudioPropagationChannelLayoutType.Binaural
    audio_sensor_spec.channelLayout.channelCount = 1
    # audio sensor location set with respect to the agent
    audio_sensor_spec.position = position
    audio_sensor_spec.acousticsConfig.sampleRate = 48000
    # whether indrect (reverberation) is present in the rendered IR
    audio_sensor_spec.acousticsConfig.indirect = True
    sim.add_sensor(audio_sensor_spec)

    audio_sensor = sim.get_agent(0)._sensors["audio_sensor"]
    audio_sensor.setAudioMaterialsJSON(material_config)


def add_audio_source(sim, source_pos):
    agent = sim.get_agent(0)
    audio_sensor = agent._sensors["audio_sensor"]
    audio_sensor.setAudioSourceTransform(source_pos + np.array([0, 0, 1.5])) # add 1.5m to the height calculation 
    new_state = agent.get_state()
    new_state.position = np.array(source_pos + np.array([2, 0, 0]))
    new_state.sensor_states = {}
    agent.set_state(new_state, True)


# sim = get_sim(
#     "data/scene_datasets/mp3d/UwV83HsGsw3/UwV83HsGsw3.glb",
#     "data/scene_datasets/mp3d/UwV83HsGsw3/UwV83HsGsw3.navmesh",
#     "data/scene_datasets/mp3d/mp3d.scene_dataset_config.json"
# )
sim = get_sim(
    "data/scene_datasets/gibson_data/gibson/Oyens.glb",
    "data/scene_datasets/gibson_data/gibson/Oyens.navmesh",
    "data/scene_datasets/gibson_data/gibson/gibson_semantic.scene_dataset_config.json"
)
# sim = get_sim(
#     "data/scene_datasets/mp3d_example/17DRP5sb8fy/17DRP5sb8fy.glb",
#     "data/scene_datasets/mp3d_example/17DRP5sb8fy/17DRP5sb8fy.navmesh",
#     "data/scene_datasets/mp3d_example/mp3d.scene_dataset_config.json"
# )

sta=sim.get_stage_initialization_template()
pprint(get_obj_data(sta))

# audio sensor has a height of 1.5m
audio_sensor_spec = add_audio_sensor(sim, [0.0, 0.0, 1.5])
source_pos = sim.pathfinder.get_random_navigable_point()
add_audio_source(sim, source_pos)

ir = np.array(sim.get_sensor_observations()["audio_sensor"])
print(ir.shape)
