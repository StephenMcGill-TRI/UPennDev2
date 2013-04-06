dofile('include.lua')
local simple_ipc = require 'simple_ipc'
local msgpack = require 'msgpack'
local camera_channel = simple_ipc.new_subscriber('camera')
local imu_channel = simple_ipc.new_subscriber('imu')
local actuator_channel = simple_ipc.new_subscriber('actuator')

camera_channel.callback = function()
  local res = camera_channel:receive()
  print('camera chanel ', #res)
end

imu_channel.callback = function()
  local res = imu_channel:receive()
  tbl = msgpack.unpack(res)
  print(tbl[1], tbl[2], tbl[3], tbl[4], tbl[5], tbl[6])
end

actuator_channel.callback = function()
  local res = actuator_channel:receive()
  local act = msgpack.unpack(res)
  print(#act)
end

local wait_channels = {imu_channel, camera_channel, actuator_channel}
local channel_poll = simple_ipc.wait_on_channels( wait_channels )

local channel_timeout = 30
while true do
  channel_poll:poll(channel_timeout)
end
