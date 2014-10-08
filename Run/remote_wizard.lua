#!/usr/bin/env luajit
-- (c) 2013, 2014 Stephen McGill, Seung-Joon Yi
dofile'../include.lua'

local RemoteControl = require'RemoteControl.ffi'
local rc

local function entry()
  rc = RemoteControl.init()
  print(rc)
end

local function update()
  rc:send():wait():receive():process()
end

-- If required from Webots, return the table
if ... and type(...)=='string' then
	return {entry=nil, update=update, exit=nil}
end

local running = true
local function shutdown()
  running = false
end
local signal = require'signal'.signal
signal("SIGINT", shutdown)
signal("SIGTERM", shutdown)

local unix = require'unix'
local t0 = unix.time()
local t_debug = t0
entry()
while running do
  local t = unix.time()
  if t-t_debug > 1 then
    print('Remote Control | Uptime:', t-t0)
    t_debug = t
  end
  update()
end