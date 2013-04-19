module(..., package.seeall);

local Body = require('Body')
local vcm = require('vcm')
local mcm = require('mcm')
local ColorLUT = require('ColorLUT')

t0 = 0;
timeout = 2.0;

enable_learning = 1

function entry()
  pitchBias =  mcm.get_headPitchBias();--robot specific head bias

  print(_NAME.." entry");

  if vcm.get_camera_learned_new_lut() == 1 then
    return 'done'
  end

  t0 = Body.get_time();

  -- set head to default position
  local yaw = 0;
  local pitch = 50*math.pi/180;

  Body.set_head_command({yaw, pitch-pitchBias});

end

function update()

  local t = Body.get_time()
  --
  pitchBias =  mcm.get_headPitchBias();--robot specific head bias
  -- set head to default position
  local yaw = 0;
  local pitch = 50*math.pi/180;

  Body.set_head_command({yaw, pitch-pitchBias});

  
  if (t - t0) > timeout then
    return 'timeout'
  end

end

function exit()
end

