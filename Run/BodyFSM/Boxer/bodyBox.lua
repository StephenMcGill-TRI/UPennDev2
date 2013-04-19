module(..., package.seeall);

local Config = require 'Config'
local Body = require('Body')
local boxercm = require('boxercm')
local walk = require('walk')
local vector = require('vector')

t0 = 0;
timeout = 5;

roll0 = 0; -- Roll offset
--vpr = 1; -- Roll to velocity ratio
vpr = 1.5; -- Tuned value
--pitch0 = 0;
pitch0 = -10*math.pi/180; -- Tuned value
pitch0 = -7.5*math.pi/180; -- Tuned value
pitch0 = -5*math.pi/180; -- Tuned value
--vpp = -1;
vpp = -0.5; -- Tuned
vpp = -0.3; -- Tuned
vpp = -0.2; -- Tuned
yaw0 = 0;
--vpy = 1;
--vpy = .5; -- Tuned value
vpy = .85; -- Tuned value

function entry()
  print("Body FSM:".._NAME.." entry");
  Speak.talk('Rock and Roll!')
  Motion.sm:add_event('walk');
  t0 = Body.get_time();
end

function update()
  local t = Body.get_time();
  walk.start()

  -- Check if there is a punch activated
  local qL = boxercm.get_body_qLArm();
  local qR = boxercm.get_body_qRArm();
  local rpy = boxercm.get_body_rpy();

  -- Add the override
  walk.upper_body_override(qL, qR, {0,-1*walk.bodyTilt,0});

  -- Add the velocity
  local vx = math.max(vpp*(rpy[2] - pitch0),-0.01);
  local vy = vpr*(rpy[1] - roll0);
  local va = vpy*(rpy[3] - yaw0);
  walk.set_velocity(vx,vy,va);

  if( boxercm.get_body_enabled() == 0 ) then
    print('Boxing disabled!')
    return "disabled";
  end

end

function exit()
  walk.upper_body_override_off()
  walk.set_velocity(0,0,0);
end
