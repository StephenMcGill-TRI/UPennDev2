--Now the Config file is entirely identical over two robots (using hostname)
IS_STEVE = true
IS_COMPETING = false

if HOSTNAME=="thor-P770ZM" or HOSTNAME=="asus"then	IS_STEVE = false end
-- Global Config
Config = {PLATFORM_NAME = 'THOROP1',demo = false,}
local exo = {'Walk','Net','FSM','World','Vision','Robot_Dale', 'Arm'}

--Config = {PLATFORM_NAME = 'THOROP2',demo = false,}
--exo = {'Walk','Net','FSM','World','Vision','Robot_Chip', 'Arm'}


-- Printing of debug messages
Config.debug = {
  webots_wizard = false,
  obstacle = false,
  follow = false,
  approach = false,
  planning = false,
  goalpost = false,
  world = false,
  feedback = false,
  armplan = true,
}


--NO BIRDWALK FOR ROBOCUP
--Config.birdwalk = 1 




Config.raise_body = true
Config.use_exact_tZMP = true
Config.use_heeltoe_walk = true
Config.heeltoe_angle = 0*DEG_TO_RAD
Config.walktraj={}
Config.walktraj.hybridwalk = "foot_trajectory_softfast"
--Config.walktraj.hybridwalk = "foot_trajectory_base"
Config.variable_tstep = true
Config.variable_support = true
Config.arm_init_timeout = true
Config.use_imu_yaw = false --use odometry for yaw

-- Tune for Webots
if IS_WEBOTS then
	if IS_STEVE then
		Config.testfile = 'test_teleop'
		Config.debug.armplan = true

	  Config.sensors = {
			ft = true,
			--feedback = 'feedback_wizard',
			--slam = 'slam_wizard',
    	--head_camera = 'camera_wizard',
    	--chest_lidar = true,
    	--head_lidar = true,
			--kinect = 'kinect2_wizard',
			--mesh = 'mesh_wizard',
		 	--world = 'world_wizard',
	  }

	else
		--Config.testfile = 'test_testbed'		
		Config.testfile = 'test_walkstuff'		
		Config.debug.armplan = false		
		Config.use_jacobian_arm_planning = true
		Config.enable_jacobian_test = false
		Config.enable_jacobian_test = true
		Config.enable_touchdown = false
		Config.raise_body = false
		Config.piecewise_step = true
	  Config.sensors = {
			ft = true,
			feedback = 'feedback_wizard',
		 	world = 'world_wizard',
	  }
	end
end


-----------------------------------
-- Load Paths and Configurations --
-----------------------------------
-- Custom Config files
local pname = {HOME, '/Config/THOROP0/?.lua;', package.path}
package.path = table.concat(pname)
if Config.demo then table.insert(exo, 'Demo') end
for _,v in ipairs(exo) do
	--print('Loading', v)
	local fname = {'Config_THOROP0_', v}
	local filename = table.concat(fname)
  assert(pcall(require, filename))
end

-- Custom motion libraries
for i,sm in pairs(Config.fsm.libraries) do
	local pname = {HOME, '/Player/', i,'/' ,sm, '/?.lua;', package.path}
	package.path = table.concat(pname)
end

-- Finite state machine paths
for sm, en in pairs(Config.fsm.enabled) do
	if en then
		local selected = Config.fsm.select[sm]
		if selected then
			local pname = {HOME, '/Player/', sm, 'FSM/', selected, '/?.lua;', package.path}
			package.path = table.concat(pname)
		else --default fsm
			local pname = {HOME, '/Player/', sm, 'FSM/', '?.lua;', package.path}
			package.path = table.concat(pname)
		end
	end
end

return Config
