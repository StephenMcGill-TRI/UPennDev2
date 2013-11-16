local state = {}
state._NAME = ...
require'hcm'
require'mcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()

local qLArm0,qRArm0, trLArm0, trRArm0, trLArm1, trARArm1

--Initial hand angle
local lhand_rpy0 = {0,0*Body.DEG_TO_RAD, -45*Body.DEG_TO_RAD}
local rhand_rpy0 = {0,0*Body.DEG_TO_RAD, 45*Body.DEG_TO_RAD}

local gripL, gripR = 1,1
local stage
local debugdata

local function get_tool_tr(tooloffsetx,tooloffsety,tooloffsetz)
  local handrpy = rhand_rpy0
  local tool_model = hcm.get_tool_model()
  local hand_pos = vector.slice(tool_model,1,3) + 
    vector.new({tooloffsetx,tooloffsety,tooloffsetz})  
  local tool_tr = {hand_pos[1],hand_pos[2],hand_pos[3],
                    handrpy[1],handrpy[2],handrpy[3] + tool_model[4]}
  return tool_tr
end

local function get_hand_tr(posx,posy,posz)
  return {posx,posy,posz, unpack(rhand_rpy0)}
end

local function update_model()
  local trRArmTarget = hcm.get_hands_right_tr_target()
  local trRArm = hcm.get_hands_right_tr()
  local tool_model = hcm.get_tool_model()
  tool_model[1],tool_model[2],tool_model[3] = 
  tool_model[1] + trRArmTarget[1] - trRArm[1],
  tool_model[2] + trRArmTarget[2] - trRArm[2],
  tool_model[3] + trRArmTarget[3] - trRArm[3]
  hcm.set_tool_model(tool_model)
end


function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  mcm.set_arm_handoffset(Config.arm.handoffset.gripper)

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()

  qLArm0 = qLArm
  qRArm0 = qRArm
  trLArm0 = Body.get_forward_larm(qLArm0)
  trRArm0 = Body.get_forward_rarm(qRArm0)  

  --Initial arm joint angles after rotating wrist
  qLArm1 = Body.get_inverse_arm_given_wrist( qLArm, {0,0,0, unpack(lhand_rpy0)})
  qRArm1 = Body.get_inverse_arm_given_wrist( qRArm, {0,0,0, unpack(rhand_rpy0)})
  trLArm1 = Body.get_forward_larm(qLArm1)
  trRArm1 = Body.get_forward_rarm(qRArm1)  

  --This sets torso compensation bias so that it becomes zero with initial arm configuration
  arm_planner:reset_torso_comp(qLArm0, qRArm0)
  arm_planner:save_boundary_condition({qLArm0, qRArm0, qLArm0, qRArm0, {0,0}})  
  arm_planner:set_hand_mass(0,0)


  arm_planner:set_shoulder_yaw_target(qLArm0[3], nil) --Lock left hand
  local wrist_seq = {{'wrist',nil,trRArm1}}
  if arm_planner:plan_arm_sequence2(wrist_seq) then stage = "wristyawturn" end  
  hcm.set_state_proceed(1)

hcm.set_tool_model({0.52,-0.02,0.00,  0*Body.DEG_TO_RAD})

  debugdata=''   
end

function state.update()
  --  print(state._NAME..' Update' )
  local t  = Body.get_time()
  local dt = t - t_update
  t_update = t   -- Save this at the last update time
  
----------------------------------------------------------
--Forward motions
----------------------------------------------------------

  if stage=="wristyawturn" then --Turn yaw angles first    
    gripL,doneL = util.approachTol(gripL,1,2,dt)  --Close gripper
    gripR,doneR = util.approachTol(gripR,1,2,dt)  --Close gripper

--  Body.set_lgrip_percent(gripL*0.8)
    Body.set_rgrip_percent(gripR*0.8)
    if arm_planner:play_arm_sequence(t) then       
      if hcm.get_state_proceed()==1 then 
        arm_planner:set_shoulder_yaw_target(qLArm0[3],nil)
        trRArmTarget1 = get_hand_tr(0.30,-0.20,-0.10)
        trRArmTarget2 = get_hand_tr(0.35,-0.20,0.05)
        local arm_seq = {{'move',nil,trRArmTarget1},{'move',nil,trRArmTarget2}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "armup" end
      elseif hcm.get_state_proceed()==-1 then 
        arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3]) 
        local wrist_seq = {{"wrist",nil,trRArm0}}
        if arm_planner:plan_arm_sequence2(wrist_seq) then stage = "armbacktoinitpos" end  
      end
    end
  elseif stage=="armup" then
    if arm_planner:play_arm_sequence(t) then stage = "initialwait" end
  elseif stage=="initialwait" then
    gripL,doneL = util.approachTol(gripL,0,2,dt)  --Open gripper
    gripR,doneR = util.approachTol(gripR,0,2,dt)  --Open gripper
    --Body.set_lgrip_percent(gripL*0.8)
    Body.set_rgrip_percent(gripR*0.8)
    if doneL then
      if hcm.get_state_proceed()==1 then 
        arm_planner:set_shoulder_yaw_target(qLArm0[3],nil)
        local trRArmTarget1 = get_tool_tr(0,-0.08,0)
        local trRArmTarget2 = get_tool_tr(0,0,0)
        local arm_seq = {{'move',nil, trRArmTarget1}, {'move',nil, trRArmTarget2}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "reachout" end
      elseif hcm.get_state_proceed()==-1 then 
        arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3]) --Lock right shoulder yaw
        trRArmTarget1 = get_hand_tr(0.25,-0.20,-0.05)
        local arm_seq = {{'move',nil,trRArmTarget1},{'move',nil,trRArm1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "wristyawturn" end  
      end
    end 
  elseif stage=="reachout" then --Move arm to the gripping position
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then 
        local trRArmTarget2 = get_tool_tr(0,0,0)
        arm_planner:set_hand_mass(0,1)    
        local arm_seq = {{'move',nil, trRArmTarget2}}     
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "grab" end
      elseif hcm.get_state_proceed() == -1 then 
        local trRArmTarget1 = get_tool_tr(0,-0.08,0)
        local trRArmTarget2 = get_hand_tr(0.35,-0.20, trRArmTarget1[3])
        local trRArmTarget3 = get_hand_tr(0.25,-0.20,-0.05)
        local arm_seq={{'move',nil,trRArmTarget1},{'move',nil,trRArmTarget2},{'move',nil,trRArmTarget3}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "armup" end
      elseif hcm.get_state_proceed() == 2 then --Model modification
        update_model()        
        local trRArmTarget2 = get_tool_tr(0,0,0)
        local arm_seq = {{'move',nil,trRArmTarget2}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "reachout" end
      end
    end
  elseif stage=="grab" then --Grip the object   
    gripL,doneL = util.approachTol(gripL,1,2,dt)
    gripR,doneR = util.approachTol(gripR,1,2,dt)
--    Body.set_lgrip_percent(gripL*0.8)
    Body.set_rgrip_percent(gripR*0.8)
--    if doneL then
    if doneR then stage = "torsobalance" end
  elseif stage=="torsobalance" then
    if arm_planner:play_arm_sequence(t) then    
      if hcm.get_state_proceed()==1 then        
        local trRArmTarget3 = get_tool_tr(0,0,0.05)
        arm_planner:set_hand_mass(0,2)   
        local arm_seq = {{'move',nil, trRArmTarget3}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "lift" end
      elseif hcm.get_state_proceed()==-1 then stage="ungrab" 

      elseif hcm.get_state_proceed() == 2 then --Model modification
        update_model()        
        local trRArmTarget2 = get_tool_tr(0,0,0)
        local arm_seq = {{'move',nil,trRArmTarget2}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "torsobalance" end
      end
    end
  elseif stage=="lift" then
    if arm_planner:play_arm_sequence(t) then    
      if hcm.get_state_proceed()==1 then        
        local trRArmTarget4 = get_tool_tr(-0.20,0,0.05)
        local trRArmTarget5 = get_hand_tr(0.20,0.0,-0.10)
        arm_planner:set_hand_mass(0,2)   
        local arm_seq = {{'move',nil,trRArmTarget4},{'move',nil,trRArmTarget5}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "liftpull" end
      elseif hcm.get_state_proceed()==-1 then 
        local trRArmTarget3 = get_tool_tr(0,0,0)
        arm_planner:set_hand_mass(0,1)   
        local arm_seq = {{'move',nil,trRArmTarget3}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "torsobalance" end
      end
    end
  elseif stage=="liftpull" then --Move arm back to holding position
    if arm_planner:play_arm_sequence(t) then    
      stage = "pulldone"
      print("SEQUENCE DONE")
      return"hold"      
    end      

----------------------------------------------------------
--Backward motions motions
----------------------------------------------------------

  elseif stage=="ungrab" then --Ungrip the object
    gripL,doneL = util.approachTol(gripL,0,2,dt)
    gripR,doneR = util.approachTol(gripL,0,2,dt)
    --Body.set_lgrip_percent(gripL*0.8)
    Body.set_rgrip_percent(gripR*0.8)    
--    if doneL then
    if doneR then
      arm_planner:set_hand_mass(0,0)   
      local trRArmTarget2 = get_tool_tr(0,0,0)
      local arm_seq = {{'move',nil, trRArmTarget2}}
      if arm_planner:plan_arm_sequence2(arm_seq) then stage = "reachout" end
    end  
  elseif stage=="armbacktoinitpos" then 
    if arm_planner:play_arm_sequence(t) then return "done" end
  end

  hcm.set_state_proceed(0)
end

function state.exit()  
  --Store boundary conditions for future state
  --arm_planner:save_boundary_condition(current_arm_endcond)
  print(state._NAME..' Exit' )
end

local function flush_debugdata()
  local savefile = string.format("Log/debugdata_%s",os.date());
  local debugfile=assert(io.open(savefile,"w")); 
  debugfile:write(debugdata);
  debugfile:flush();
  debugfile:close();  
end

return state