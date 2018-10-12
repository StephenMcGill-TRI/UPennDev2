#!/usr/bin/env luajit
local flags = require'racecar'.parse_arg(arg)
local devname = flags.uvc or '/dev/video0'

local uvc = require'uvc'

local time = require'unix'.time
local racecar = require'racecar'
racecar.init()
local log_announce = racecar.log_announce
local jitter_tbl = racecar.jitter_tbl

-- local width, height = 1344, 376
-- local width, height = 640, 480
local width, height = 320, 240
local fmt = flags.fmt or 'yuyv'
local camera = assert(uvc.init(devname, width, height, fmt, 1, 10))

local c_jpeg
if fmt=='yuyv' then
  local jpeg = require'jpeg'
  c_jpeg = jpeg.compressor'yuyv'
  -- c_jpeg:downsampling(1)
  c_jpeg:downsampling(0)
elseif fmt == 'mjpeg' then
  c_jpeg = nil
  -- local ffi = require'ffi'
  -- c_jpeg = function(ptr, sz) return ffi.string(ptr, sz) end
end

local channel = devname:match("([^/]+%d+)") or 'camera'
local logger = require'logger'
local log = flags.log~=0 and assert(logger.new(channel, racecar.ROBOT_HOME.."/logs"))

local function exit()
  if log then log:close() end
  camera:close()
  return 0
end
racecar.handle_shutdown(exit)

local t_debug = time()
local n = 0
while racecar.running do
  local img, sz = camera:get_image(-1, not c_jpeg)
  local t = time()
  if img then
    local img_jpg = nil
    if c_jpeg then
      img_jpg = c_jpeg:compress(img, sz, width, height)
    elseif fmt == 'mjpeg' then
      img_jpg = img
    end
    local obj = {
      t = t, jpg = img_jpg
    }
    log_announce(log, obj, channel)
    n = n + 1
  end
  local dt_debug = t - t_debug
  if dt_debug > 1 then
    io.write(table.concat(jitter_tbl(), '\n'), '\n')
    t_debug = t
    n = 0
  end
end
exit()
