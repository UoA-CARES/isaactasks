```yaml
task: AllegroHand
env_name: allegro_hand
description: to make the hand spin the object to a target orientation 
max_iterations: 5000
Task Name: Template-Allegro-Hand-Direct-v0
Entry Point: isaaclab_tasks.direct.inhand_manipulation.inhand_manipulation_env:InHandManipulationEnv
Config: isaaclab_tasks.direct.allegro_hand.allegro_hand_env_cfg:AllegroHandEnvCfg
```

```yaml

env_name: ant
description: to make the ant run forward as fast as possible
Task Name: Template-Ant-Direct-v0

Entry Point: isaaclab_tasks.direct.ant.ant_env:AntEnv
Config: isaaclab_tasks.direct.ant.ant_env:AntEnvCfg
```

```yaml

env_name: anymal
description: to make the quadruped follow randomly chosen x,y, and yaw target velocities
max_iterations: 1000
Task Name: Template-Anymal-Direct-v0

Entry Point: isaaclab_tasks.direct.anymal_c.anymal_c_env:AnymalCEnv
Config: isaaclab_tasks.direct.anymal_c.anymal_c_env_cfg:AnymalCFlatEnvCfg
```

```yaml

env_name: cartpole
description: to balance a pole on a cart so that the pole stays upright
Task Name: Template-Cartpole-Direct-v0

Entry Point: isaaclab_tasks.direct.cartpole.cartpole_env:CartpoleEnv
Config: isaaclab_tasks.direct.cartpole.cartpole_env:CartpoleEnvCfg
```

```yaml

env_name: franka_cabinet
description: to open the cabinet door
max_iterations: 1500
Task Name: Template-Franka-Cabinet-Direct-v0

Entry Point: isaaclab_tasks.direct.franka_cabinet.franka_cabinet_env:FrankaCabinetEnv
Config: isaaclab_tasks.direct.franka_cabinet.franka_cabinet_env:FrankaCabinetEnvCfg
```

```yaml

env_name: humanoid # Environment file name
description: to make the humanoid run as fast as possible
Task Name: Template-Humanoid-Direct-v0

Entry Point: isaaclab_tasks.direct.humanoid.humanoid_env:HumanoidEnv
Config: isaaclab_tasks.direct.humanoid.humanoid_env:HumanoidEnvCfg

```

```yaml

env_name: amp/humanoid_amp_base
description: to make the humanoid do a moon walk with feet sliding off the ground alternatingly to move backward
Task Name: Template-Humanoid-Amp-Base-Direct-v0

Entry Point: isaaclab_tasks.direct.humanoid_amp.humanoid_amp_env:HumanoidAmpEnv
Config: isaaclab_tasks.direct.humanoid_amp.humanoid_amp_env_cfg:HumanoidAmpDanceEnvCfg

```

```yaml

env_name: ingenuity
description: to NASA's Ingenuity helicopter to navigate to a moving target
Task Name: Template-Ingenuity-Direct-v0

Entry Point: isaaclab_tasks.direct.inhand_manipulation.inhand_manipulation_env:InHandManipulationEnv
Config: isaaclab_tasks.direct.shadow_hand.shadow_hand_env_cfg:ShadowHandEnvCfg

```

```yaml

env_name: quadcopter
description: to make the quadcopter reach and hover near a fixed position
Task Name: Template-Quadcopter-Direct-v0

Entry Point: isaaclab_tasks.direct.quadcopter.quadcopter_env:QuadcopterEnv
Config: isaaclab_tasks.direct.quadcopter.quadcopter_env:QuadcopterEnvCfg
```

```yaml

env_name: shadow_hand
description: to make the shadow hand spin the object to a target orientation
Task Name: Template-Shadow-Hand-Direct-v0

Entry Point: isaaclab_tasks.direct.inhand_manipulation.inhand_manipulation_env:InHandManipulationEnv
Config: isaaclab_tasks.direct.shadow_hand.shadow_hand_env_cfg:ShadowHandEnvCfg
```


unit_5 = units_2048_1024_512_256

unit_6 = units_2048_2048_1024_512   8*

unit_7 = units_2048_1024_1024_512   4*

unit_8 = units_2048_2048_1024_256   4*

unit_9 = units_2048_2048_512_512     4*

unit_10 = units_2048_1024_512_512     2*

unit_11 = units_2048_1024_1024_256     2*

unit_12 = units_2048_2048_512_256     2*

unit_13 = units_4096_1024_512_256     2*

512*512*256*128

num_envs=8192

16384

32768

65536

5K