# Copyright (c) 2022-2025, The Isaac Lab Project Developers.
# All rights reserved.
# (-0.07, -0.16, 0.5)
#
# SPDX-License-Identifier: BSD-3-Clause

"""Configuration for the Allegro Hand robots from Wonik Robotics.

The following configurations are available:

* :obj:`ALLEGRO_HAND_CFG`: Allegro Hand with implicit actuator model.

Reference:

* https://www.wonikrobotics.com/robot-hand

"""

import math
import isaaclab.sim as sim_utils
from isaaclab.actuators.actuator_cfg import ImplicitActuatorCfg
from isaaclab.assets.articulation import ArticulationCfg

UOA_HAND_CONFIG = ArticulationCfg(
    prim_path="/World/envs/env_.*/Robot",
    spawn=sim_utils.UsdFileCfg(
        usd_path="/home/lee/code/isaactasks/masa_hand/Assets/uoa_hand_v5.usd",
        # VERY IMPORTANT
        joint_drive_props=sim_utils.JointDrivePropertiesCfg(drive_type="force"),
        # fixed_tendons_props=sim_utils.FixedTendonPropertiesCfg(limit_stiffness=30.0, damping=0.1),
        activate_contact_sensors=False,
        rigid_props=sim_utils.RigidBodyPropertiesCfg(
            disable_gravity=True,
            retain_accelerations=False,
            enable_gyroscopic_forces=False,
            angular_damping=0.01,
            max_linear_velocity=1.0,
            max_angular_velocity=40,
            max_depenetration_velocity=10.0,
            max_contact_impulse=1e32,
        ),
        articulation_props=sim_utils.ArticulationRootPropertiesCfg(
            enabled_self_collisions=True,
            solver_position_iteration_count=8,
            solver_velocity_iteration_count=0,
            sleep_threshold=0.005,
            stabilization_threshold=0.0005,
            fix_root_link=True,  # Fix the base in space
        ),
        # collision_props=sim_utils.CollisionPropertiesCfg(contact_offset=0.005, rest_offset=0.0),
    ),
    init_state=ArticulationCfg.InitialStateCfg(
        pos=(-0.12, -0.16, 0.4),
        rot=(1., 0, 0, 0),
        # joint_pos={".*": 0.001},
        joint_pos={
            "thumb_carpal_1_thumb_abd0": 0.0,
            "middle_1_m_pp_1_middle_mcp0": -0.174,
            "palm_2_1_palm_abd0": 0.0,
            "index_1_i_pp_1_index_mcp0": -0.174,
            "thumb_1_t_pp_1_thumb_mcp0": -0.174,
            "middle_1_m_pp_1_middle_mcp1": 0.0,
            "ring_1_r_pp_1_ring_mcp0": -0.174,
            "pinky_1_p_pp_1_pinky_mcp0": -0.174,
            "index_1_i_pp_1_index_mcp1": 0.0,
            "thumb_1_t_pp_1_thumb_mcp1": -0.349,
            "middle_1_m_pp_1_middle_mcp2": -0.349,
            "ring_1_r_pp_1_ring_mcp1": 0.0,
            "pinky_1_p_pp_1_pinky_mcp1": 0.0,
            "index_1_i_pp_1_index_mcp2": -0.349,
            "thumb_1_t_pp_1_thumb_mcp2": -0.523,
            "middle_1_m_ip_1_m_pp_ip0": 0.0,
            "ring_1_r_pp_1_ring_mcp2": -0.349,
            "pinky_1_p_pp_1_pinky_mcp2": -0.349,
            "index_1_i_ip_1_i_pp_ip0": 0.0,
            "thumb_1_t_ip_1_t_pp_ip0": 0.0,
            "middle_1_m_dp_1_m_ip_pp0": 0.0,
            "ring_1_r_ip_1_r_pp_ip0": 0.0,
            "pinky_1_p_ip_1_p_pp_ip0": 0.0,
            "index_1_i_dp_1_i_ip_dp0": 0.0,
            "thumb_1_t_dp_1_t_ip_dp0": 0.0,
            "ring_1_r_dp_1_r_ip_dp0": 0.0,
            "pinky_1_p_dp_1_p_ip_dp0": 0.0,
        },
    ),
    actuators={
        "fingers": ImplicitActuatorCfg(
            joint_names_expr=[".*"],
            velocity_limit_sim=50.0,  # deg/s (deg because of USD convention)
            # stiffness=1e+6,
            # damping=1e+4,
            stiffness=10,
            damping=0.1,
            friction=0.8,
            dynamic_friction=0.6,
            effort_limit_sim=3,
        ),
    },
    soft_joint_pos_limit_factor=0.95,
)