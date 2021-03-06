local state = {}
state._NAME = ...

local Body = require'Body'
local util = require'util'
require'wcm'


local t_entry, t_update
local stage
local DEG_TO_RAD = math.pi/180


--SJ: Adult sized league doesn't need too complicated stuff
--SO let's just define params directly on the fsm files

local dqNeckLimit = {180*DEG_TO_RAD, 180*DEG_TO_RAD}

--Pitch: 25 degree down can see up to 5 meters 
--60 degree down can see ball right in front

function state.entry()
  print(state._NAME..' Entry' )
  -- When entry was previously called
  local t_entry_prev = t_entry
  -- Update the time of entry
  t_entry = Body.get_time()
  t_update = t_entry
  stage = 1
  wcm.set_ball_disable(0)
  wcm.set_goal_disable(1)
  wcm.set_obstacle_enable(0)
  wcm.set_ball_backonly(0)
end

function state.update()
  -- print(_NAME..' Update' )
  -- Get the time of update
  local t = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  if gcm.get_game_state()~=3 then return end


  local qNeck0 = Body.get_head_command_position()
  local headBias = hcm.get_camera_bias()
  qNeck0[1] = qNeck0[1] - headBias[1]  

  local yawTarget, pitchTarget

  if stage==1 then
    pitchTarget = 55*DEG_TO_RAD
    yawTarget = 45*DEG_TO_RAD
  elseif stage==2 then
    dqNeckLimit = {60*DEG_TO_RAD, 60*DEG_TO_RAD}
    pitchTarget = 55*DEG_TO_RAD
    yawTarget = -45*DEG_TO_RAD
  elseif stage==3 then
    pitchTarget = 25*DEG_TO_RAD        
    yawTarget = -45*DEG_TO_RAD
  elseif stage==4 then
    pitchTarget = 25*DEG_TO_RAD    
    yawTarget = 45*DEG_TO_RAD
  else
    if gcm.get_game_role()~=0 then --
      return 'noball'    
    else
      --goalie keep scanning
      stage=1
      return
    end
  end

  local qNeck_approach, doneNeck = 
    util.approachTol( qNeck0, {yawTarget,pitchTarget}, dqNeckLimit, dt )
  if doneNeck then stage = stage+1 end

  -- Update the motors
--  Body.set_head_command_position(qNeck_approach)

  local headBias = hcm.get_camera_bias()
  Body.set_head_command_position({qNeck_approach[1]+headBias[1],qNeck_approach[2]})

  -- Check if we found the ball
  local ball_elapsed = t - wcm.get_ball_t()

  wcm.set_ball_tlook(t)
  if wcm.get_ball_t()>wcm.get_ball_tlook() then
    wcm.set_ball_tlook(wcm.get_ball_t())
  end

  if ball_elapsed < 0.1 then    
    return 'ballfound' --if ball found exit
  end


--  if gcm.get_game_state()~=3 and gcm.get_game_state()~=5 and gcm.get_game_state()~=6 then return'teleop' end
  
end

function state.exit()

  
  print(state._NAME..' Exit'..' total time:'..Body.get_time()-t_entry )
end

return state

