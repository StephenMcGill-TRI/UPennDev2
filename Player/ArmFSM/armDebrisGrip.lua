local state = {}
state._NAME = ...
require'hcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()

--SJ: Now we assume we have STRAIGHT gripper


local lhand_rpy0 = {90*Body.DEG_TO_RAD,0,0}
local rhand_rpy0 = {-90*Body.DEG_TO_RAD,0,0}

local trLArm0, trRArm0, trLArm1, trRArm1, qLArm0, qRArm0
local stage

local qLArmInit0,qRArmInit0,qLArmInit1,qRArmInit1

local gripL, gripR = 1,1 --start closed

local function getTargetTransform(offset, handrpy)
  local debris_model = hcm.get_debris_model()
  offset = offset or {0,0,0}
  handrpy = handrpy or lhand_rpy0
  local trArmTarget = {
    debris_model[1]+offset[1],
    debris_model[2]+offset[2],
    debris_model[3]+offset[3],        
    unpack(handrpy)}  

  lhand_rpy0 = {0,0,debris_model[4]}

  return trArmTarget
end

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  --TODO
  mcm.set_arm_handoffset(Config.arm.handoffset.chopstick)

  hcm.set_debris_model({0.50,0.25,0.02,    0})  
  getTargetTransform() --This sets hand rpy angle using hcm

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()
  
  qLArm0 = qLArm
  qRArm0 = qRArm

  trLArm0 = Body.get_forward_larm(qLArm0)
  trRArm0 = Body.get_forward_rarm(qRArm0)  
  
  local qLArm1 = Body.get_inverse_arm_given_wrist( qLArm, {0,0,0, unpack(lhand_rpy0)})
  local qRArm1 = Body.get_inverse_arm_given_wrist( qRArm, {0,0,0, unpack(rhand_rpy0)})

  trLArm1 = Body.get_forward_larm(qLArm1)
  trRArm1 = Body.get_forward_rarm(qRArm1)  

  arm_planner:reset_torso_comp(qLArm0, qRArm0)
  arm_planner:save_boundary_condition({qLArm0, qRArm0, qLArm0, qRArm0, {0,0}})

  arm_planner:set_shoulder_yaw_target(nil,qRArm0[3]) --Lock right shoulder yaw
  local wrist_seq = { armseq={ {trLArm1,trRArm0}} }
  if arm_planner:plan_wrist_sequence(wrist_seq) then stage = "wristturn" end  
  hcm.set_state_proceed(1)
end

local function update_model()
  local trLArmTarget = hcm.get_hands_left_tr_target()
  local trLArm = hcm.get_hands_left_tr()
  local debris_model = hcm.get_debris_model()
  debris_model[1],debris_model[2],debris_model[3]=
    debris_model[1] + trLArmTarget[1]-trLArm[1],
    debris_model[2] + trLArmTarget[2]-trLArm[2],
    debris_model[3] + trLArmTarget[3]-trLArm[3]
  hcm.set_debris_model(debris_model)
end


function state.update()
--  print(state._NAME..' Update' )
  -- Get the time of update
  if plan_failed then return "planfail" end
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()
  local trLArm = Body.get_forward_larm(qLArm)

  if stage=="wristturn" then --Turn yaw angles first
    if arm_planner:play_arm_sequence(t) then           
      if hcm.get_state_proceed()==1 then
        print("Current:",arm_planner.print_transform(trLArm))
        local trLArmTarget1 = {0.35,0.25, -0.10, unpack(lhand_rpy0)}      
        local trLArmTarget2 = {0.35,0.25, 0.0, unpack(lhand_rpy0)}
        local arm_seq = {
          mass={0,0},
          armseq={ {trLArmTarget1,trRArm0 }, {trLArmTarget2, trRArm0 }}
        }
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armfront" end      
      elseif hcm.get_state_proceed()==-1 then
        arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3])
        local wrist_seq = {  armseq={ {trLArm0,trRArm0 }}}    
        if arm_planner:plan_wrist_sequence(wrist_seq) then stage = "armbacktoinitpos" end      
      end
    end
  elseif stage=="armfront" then       
    gripL,doneL = util.approachTol(gripL,1,2,dt) --close gripper
    Body.set_lgrip_percent(gripL*0.8)   
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then
        local trLArmTarget1 = getTargetTransform()
        trLArmTarget1[1] = 0.35
        local trLArmTarget2 = getTargetTransform({-0.08,0,0})        
        local arm_seq = { armseq={ {trLArmTarget1,trRArm0 }, {trLArmTarget2, trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armposition" end      
      elseif hcm.get_state_proceed()==-1 then
        local trLArmTarget1 = {0.35,0.25, -0.10, unpack(lhand_rpy0)}      
        local arm_seq = {armseq={ {trLArmTarget1,trRArm0 },{trLArm1,trRArm0 } }}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "wristturn" end              
      end
    end
  elseif stage=="armposition" then --Move the arm forward using IK now  
    gripL,doneL = util.approachTol(gripL,0,2,dt) --open gripper
    Body.set_lgrip_percent(gripL*0.8)   

    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed(0)==1 then
        local trLArmTarget1 = getTargetTransform()
        local arm_seq = { armseq={ {trLArmTarget1,trRArm0 } }}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armpositiongrab" end
      elseif hcm.get_state_proceed(0)==2 then --modification
        update_model()
        local trLArmTarget2 = getTargetTransform({-0.08,0,0})        
        local arm_seq = { armseq={ {trLArmTarget2, trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armposition" end      
      elseif hcm.get_state_proceed(0)==-1 then --go back to center position        
        local trLArmTarget1 = {0.35,0.25, 0.0, unpack(lhand_rpy0)}
        local arm_seq = { armseq={ {trLArmTarget1,trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armfront" end      
      end
    end
  elseif stage=="armpositiongrab" then           
    gripL,doneL = util.approachTol(gripL,0,2,dt) --open gripper
    Body.set_lgrip_percent(gripL*0.8)   
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then
        stage="grab" 
      elseif hcm.get_state_proceed()==2 then   
        update_model()
        local trLArmTarget2 = getTargetTransform()        
        local arm_seq = { armseq={ {trLArmTarget2, trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armpositiongrab" end      
      elseif hcm.get_state_proceed(0)==-1 then 
        local trLArmTarget2 = getTargetTransform({-0.08,0,0})
        trLArmTarget2[1] = math.max(0.35,trLArmTarget2[1])
        local arm_seq = { armseq={ {trLArmTarget2, trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "armposition" end      
      end
    end
  elseif stage=="grab" then           
    gripL,doneL = util.approachTol(gripL,1,2,dt) --close gripper
    Body.set_lgrip_percent(gripL*0.8)   
    if doneL then 
      if hcm.get_state_proceed(0)==1 then

      elseif hcm.get_state_proceed(0)==2 then
        update_model()
        local trLArmTarget2 = getTargetTransform()        
        local arm_seq = { armseq={ {trLArmTarget2, trRArm0 }}}
        if arm_planner:plan_arm_sequence(arm_seq) then stage = "grabmove" end      
      elseif hcm.get_state_proceed(0)==-1 then 
        stage="armpositiongrab"
      end
    end
  elseif stage=="grabmove" then           
    if arm_planner:play_arm_sequence(t) then stage="grab" end    
  elseif stage=="armbacktoinitpos" then  
    if arm_planner:play_arm_sequence(t) then      
      return "done"
    end
  end
 
 hcm.set_state_proceed(0)
end

function state.exit()  
  print(state._NAME..' Exit' )
end

return state
