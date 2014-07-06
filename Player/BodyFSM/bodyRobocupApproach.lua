local state = {}
state._NAME = ...
local Body   = require'Body'
local util   = require'util'
local vector = require'vector'
local libStep = require'libStep'
-- FSM coordination
local simple_ipc = require'simple_ipc'
local motion_ch = simple_ipc.new_publisher('MotionFSM!')


-- Get the human guided approach
require'hcm'
-- Get the robot guided approach
require'wcm'

require'mcm'


local step_planner
local t_entry, t_update, t_exit
local nwaypoints, wp_id
local waypoints = {}

local target_pose
local uLeft_now, uRight_now, uTorso_now, uLeft_next, uRight_next, uTorso_next
local supportLeg
local ball_side = 1

local last_ph = 0



local function robocup_approach( pose, target_pose)
  local maxStep = 0.04
  local maxTurn = 0.15
  local dist_threshold = Config.fsm.bodyRobocupFollow.th_dist
  local angle_threshold = .1

  -- Distance to the waypoint
  local rel_pose = util.pose_relative(target_pose,pose)
  local rel_dist = math.sqrt(rel_pose[1]*rel_pose[1]+rel_pose[2]*rel_pose[2])

  -- calculate walk step velocity based on ball position
  local vStep = vector.zeros(3)
  -- TODO: Adjust these constants
  vStep[1] = math.min(maxStep,math.max(-maxStep,rel_pose[1]))
  vStep[2] = math.min(maxStep,math.max(-maxStep,rel_pose[2]))
  vStep[3]=0

  -- Reduce speed based on how far away from the waypoint we are
  if rel_dist < 0.1 then maxStep = 0.02 end
  local scale = math.min(maxStep/math.sqrt(vStep[1]^2+vStep[2]^2), 1)
  vStep = scale * vStep
 
  return vStep, false
end

local function update_velocity()
  local pose = wcm.get_robot_pose()
  local foot_xOffset = 0.30
  local ballx = wcm.get_ball_x() - Config.fsm.bodyRobocupApproach.target[1]
  local bally = wcm.get_ball_y() - ball_side*Config.fsm.bodyRobocupApproach.target[2]
  local ballr = math.sqrt(ballx*ballx+bally*bally)
  local balla = math.atan2(bally,ballx)
  local walk_target_local = {ballx,bally,balla}
  local target_pose = util.pose_global(walk_target_local, pose)

  

  local vStep,arrived = robocup_approach( pose, target_pose)
  mcm.set_walk_vel(vStep)


  local t  = Body.get_time()
  local ball_elapsed = t - wcm.get_ball_t()

  if Config.debug.approach then
    print(string.format("Ball pos: x %.3f y %.3f",wcm.get_ball_x(), wcm.get_ball_y() ))
    print(string.format("Ball err: x %.3f y%.3f   %.2f elapsed", ballx,bally,ball_elapsed))
    print("Approach vel:",vStep[1],vStep[2],vStep[3])
  end


  if ballr > 1.0 then 
    print("Ball distance too away at:",ballr)
    return 'ballfar' 
  end


  if ball_elapsed <0.5 
    and ballx<Config.fsm.bodyRobocupApproach.th[1]
    and math.abs(bally)<Config.fsm.bodyRobocupApproach.th[2] then

    print("Final ball pos:",wcm.get_ball_x(),wcm.get_ball_y())
    if ball_side==1 then
      mcm.set_walk_kickfoot(0)--left foot kick
    else
      mcm.set_walk_kickfoot(1)--right foot kick
    end
    mcm.set_walk_kicktype(0) --this means real mode (keep run body fsm after kicking)
    if Config.use_walkkick then
      return "walkkick"
    else
      return 'done'
    end
  end
end


function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  local ret = nil

  t_entry = Body.get_time()
  t_update = t_entry
  
  local bally = wcm.get_ball_y()
  print(string.format("Initial ball pos:%.2f %.2f",
    wcm.get_ball_x(), wcm.get_ball_y()
    ))
  if bally<0 then
    print("Ball right")
    ball_side = -1
  else
    print("Ball left")
    ball_side = 1
  end
  last_ph = 0
end

function state.update()
  --print(state._NAME..' Update' )
  -- Get the time of update
  local ret = nil
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  local check_ph = 0.95
  local ph = mcm.get_status_ph()
  if last_ph<check_ph and ph>=check_ph then ret=update_velocity() end
  last_ph = ph
  return ret
end

function state.exit()
  print(state._NAME..' Exit' )
end

return state
