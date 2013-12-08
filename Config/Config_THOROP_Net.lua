-- Tune this parameter if being used for testing
local USE_LOCALHOST = false
local USE_LOCALHOST = true

local Config = {}
Config.USE_LOCALHOST = USE_LOCALHOST

----------------------
-- Network settings --
----------------------
-- TODO: Verify with ifconfig
Config.net = {}
-- Robot IP addresses
Config.net.robot = {
['wired']    = '192.168.123.26',
['wireless'] = '192.168.1.26',
}

-- Remote Operator IP addresses
Config.net.operator = {
----[[
['wired']              = '192.168.123.23',
['wired_broadcast']    = '192.168.123.255',
--]]
--[[
['wired']              = '158.130.111.134',
['wired_broadcast']    = '158.130.111.255',
--]]
--
['wireless']           = '192.168.1.23',
['wireless_broadcast'] = '192.168.1.255'
}

-- For use only when testing in webots on a local computer
if Config.USE_LOCALHOST then
  -- wired
  Config.net.robot.wired = 'localhost'
  Config.net.operator.wired = 'localhost'
  Config.net.operator.wired_broadcast = 'localhost'
  -- wireless
  Config.net.robot.wireless = 'localhost'
  Config.net.operator.wireless = 'localhost'
  Config.net.operator.wireless_broadcast = 'localhost'
end

-- Ports
Config.net.reliable_rpc   = 55555
Config.net.unreliable_rpc = 55556
--
Config.net.team           = 44444
Config.net.state          = 44445
--
Config.net.camera = {}
Config.net.camera.head     = 33333
Config.net.camera.forehead = 33335
Config.net.camera.forehead2 = 33337
--
Config.net.reliable_camera = {}
Config.net.reliable_camera.head     = 33334
Config.net.reliable_camera.forehead = 33336
Config.net.reliable_camera.forehead2 = 33338
--
Config.net.mesh           = 33344
Config.net.reliable_mesh  = 33345
Config.net.rgbd_depth     = 33346
Config.net.rgbd_color     = 33347
--
Config.net.omap           = 22222
Config.net.hmap           = 22223

Config.net.feedback       = 54329

return Config
