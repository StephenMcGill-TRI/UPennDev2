local state = {}
state._NAME = ...
require'hcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()

--Door opening state using HOOK
local handle_clearance = vector.new({0,0,-0.05})
local lhand_rpy0 = {0*Body.DEG_TO_RAD,0,0}
local rhand_rpy0 = {-0*Body.DEG_TO_RAD,0,0}
local trLArm1, trRArm1
local stage

local qLArmInit0,qRArmInit0

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()

  arm_planner:reset_torso_comp(qLArm, qRArm)
  arm_planner:save_boundary_condition({qLArm, qRArm, qLArm, qRArm, {0,0}})
  
  arm_planner:set_shoulder_yaw_target(nil,nil)

  trLArm = Body.get_forward_larm(qLArm)
  print(unpack(vector.new(trLArm)*Body.RAD_TO_DEG))
  
  qLArm0 = Body.get_inverse_arm_given_wrist( qLArm, {0,0,0, unpack(lhand_rpy0)})  
  qRArm0 = Body.get_inverse_arm_given_wrist( qRArm, {0,0,0, unpack(rhand_rpy0)})
  
  trLArm0 = Body.get_forward_larm(qLArm0)
  trRArm0 = Body.get_forward_rarm(qRArm0)  

  hcm.set_hands_left_tr(trLArm0)
  hcm.set_hands_right_tr(trRArm0)
  hcm.set_hands_left_tr_target(trLArm0)
  hcm.set_hands_right_tr_target(trRArm0)
    
  local wrist_seq = {  armseq={{trLArm0, trRArm0}}  }
  if arm_planner:plan_wrist_sequence(wrist_seq) then   
    stage = "wristturn"
  end
end


function state.update()
--  print(state._NAME..' Update' )
  -- Get the time of update
  if plan_failed then return "planfail" end
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --if t-t_entry > timeout then return'timeout' end
  
  if stage=="wristturn" then --Turn yaw angles first
--[[    
    if movearm.setArmJoints(qLArm0,qRArm0,dt, Config.arm.joint_init_limit) ==1 then       
      stage = "teleopwait"      
    end
--]]
    if arm_planner:play_arm_sequence(t) then 
      stage="teleopwait"
    end
  elseif stage=="teleopwait" then       

  local qLArm = Body.get_larm_command_position()
  print(unpack(vector.new(qLArm)*Body.RAD_TO_DEG))



    if hcm.get_state_proceed(0)==2 then --teleop signal
      local trLArmTarget=  hcm.get_hands_left_tr_target()
      local trRArmTarget=  hcm.get_hands_right_tr_target()
      local arm_seq = {
        mass={0,0},
        armseq={
          {trLArmTarget, trRArmTarget},          
        }
      }
      if arm_planner:plan_arm_sequence(arm_seq) then 
        stage="teleopmove" 
        hcm.set_hands_left_tr(trLArmTarget)
        hcm.set_hands_right_tr(trRArmTarget)
      else        
      end
    end
  elseif stage=="teleopmove" then 
    if arm_planner:play_arm_sequence(t) then 
      stage="teleopwait"
    end
  end
  hcm.set_state_proceed(0)
end

function state.exit()  
  print(state._NAME..' Exit' )
end

return state
