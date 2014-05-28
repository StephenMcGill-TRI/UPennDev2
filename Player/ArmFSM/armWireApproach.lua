--------------------------------
-- Approach Wire
-- (c) 2014 Stephen McGill
--------------------------------
local state = {}
state._NAME = ...

local Body   = require'Body'
local util   = require'util'
local vector = require'vector'
local K = Body.Kinematics
local T = require'libTransform'
local t_entry, t_update, t_finish
local timeout = 10.0
local get_time = Body.get_time

local lost_timeout = Config.fsm.armWireApproach.lost_timeout
local thresh_yaw = Config.fsm.armWireApproach.thresh_yaw
local thresh_roll = Config.fsm.armWireApproach.thresh_roll
local roll_rate = Config.fsm.armWireApproach.roll_rate
local yaw_rate = Config.fsm.armWireApproach.yaw_rate
local approach_rate = Config.fsm.armWireApproach.approach_rate
local wire_close = Config.fsm.armWireApproach.wire_close

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = get_time()
  t_update = t_entry
  t_finish = t
end

function state.update()
  --print(state._NAME..' Update' )
  local t  = get_time()
  local dt = t - t_update
  local dt_entry = t - t_entry
  if dt_entry>timeout then
    return'timeout'
  end
  -- Save this at the last update time
  t_update = t
  -- Have we seen the wire recently?
  local wire_dt = t - vcm.get_wire_t()
  if wire_dt>lost_timeout then
    return'lost'
  end
  -- Check if we are too far from the wire, and should re-align
  local cam_roll, cam_pitch, cam_yaw = unpack(vcm.get_wire_cam_rpy())
  --if math.abs(cam_roll)>thresh_roll or math.abs(cam_yaw)>thresh_yaw then
  if math.abs(cam_roll)>thresh_roll then
    return'far'
  end
  -- Check how close we are to the item
  local wire_r, wire_d, wire_t = unpack(vcm.get_wire_model())
  -- Camera is mounted this far from the gripper
  -- TODO: Place this magic number in a Config file somewhere
  --print(wire_r, wire_d, wire_t)
  if wire_d < wire_close and wire_t > 1 then
    return 'close'
  end

  -- Find where we should go now
  --local qLArm = .25 * Body.get_larm_position() + .75 * Body.get_larm_command_position()
  local qLArm = 0 * Body.get_larm_position() + 1 * Body.get_larm_command_position()
  -- Find the kinematics
  local fkLArm = K.forward_arm(qLArm)
  -- Step in the direction of the gripper (z for youbot...)
  --local fkLArm_next = fkLArm * T.trans(0, 0, approach_rate * dt)
  local fkLArm_next = fkLArm * T.trans(0, 0, approach_rate)
  local iqArm_next = vector.new(K.inverse_arm(fkLArm_next, qLArm))
  -- TODO: Add small changes on the local camera roll and camera yaw
  -- These are independent of the IK in the local z direction
  -- Use a simple P controller. TODO: Is PID worth it?
  iqArm_next[5] = qLArm[5] + (cam_roll - 0) * roll_rate * dt
  --iqArm_next[1] = qLArm[1] + (cam_yaw - 0)* yaw_rate * dt
  -- Go to the waypoint
  Body.set_larm_command_position(iqArm_next)
end

function state.exit()
  print(state._NAME..' Exit' )
end

return state