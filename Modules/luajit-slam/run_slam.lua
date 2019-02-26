#!/usr/bin/env luajit

local DEG_TO_RAD = math.pi/180
local RAD_TO_DEG = 180/math.pi
local cos = require'math'.cos
local sin = require'math'.sin
local floor = require'math'.floor
local pow = require'math'.pow
local sqrt = require'math'.sqrt
local tinsert = require'table'.insert
--
local slam = require'slam'
local tf = require'transform'
local quaternion = require'quaternion'
local vnew = require'vector'.new
local vnorm = require'vector'.norm
local vunit = require'vector'.unit
local time = require'unix'.time
local usleep = require'unix'.usleep
local time_us = require'unix'.time_us
local has_png, png = pcall(require, 'png')
local has_kalman, kalman = pcall(require, 'kalman')
--
local racecar = require'racecar'
local flags = require'racecar'.parse_arg(arg)
local log_announce = require'racecar'.log_announce
--
local logger = require'logger'
local fnames = {}
for i,flag in ipairs(flags) do
  if flag:match(logger.iso8601_match) then
    tinsert(fnames, flag)
  end
end
assert(#fnames > 0, "No logs to replay")

local ENABLE_AUTO_BIAS = flags.enable_auto_bias ~= 0
local ENABLE_IMU_REMAP = flags.enable_imu_remap ~= 0
local realtime = flags.realtime ~= 0

-- callbacks
local update = setmetatable({}, {
  __index = function(t, k)
    return function(obj)
      if realtime then log_announce(false, obj, k) end
    end
  end
})

----------- IMU -----------
local gyro_bias = {count = 0, mean=vnew{0, 0, 0}, variance=vnew{0,0,0}}
local acc_bias = {count = 0, mean=vnew{0, 0, 0}, variance=vnew{0,0,0}}
local ukf = kalman.ukf()
local q_imu_to_rbt = quaternion.from_angle_axis(
      math.pi, {1,1,0})
local q_imu_to_rbt_inv = quaternion.conjugate(q_imu_to_rbt)
local rbt0_to_rbt = tf.eye()

local t_last_imu, accel_last, gyro_last
function update.imu(obj)
  local t_imu = obj.timeM
  local dt_imu = tonumber(t_imu - (t_last_imu or t_imu)) / 1e3
  t_last_imu = t_imu

  -- Perform the re-mapping for the robot
  local q_imu = obj.q and #obj.q==4 and quaternion.unit(obj.q * q_imu_to_rbt_inv)
  local accel, gyro
  if ENABLE_IMU_REMAP then
    accel = vnew{obj.accel[2], obj.accel[1], -obj.accel[3]}
    gyro = DEG_TO_RAD * vnew{obj.gyro[2], obj.gyro[1], -obj.gyro[3]}
  else
    accel, gyro = vnew(obj.accel), vnew(obj.gyro) * DEG_TO_RAD
  end

  -- Find the accelerometer bias at startup
  if ENABLE_AUTO_BIAS and (acc_bias.count < 300) then
    acc_bias.count = acc_bias.count + 1
    if acc_bias.count == 1 then
      acc_bias.mean = vnew{unpack(accel)}
      acc_bias.variance = 0 * vnew{unpack(accel)}
    else
      local mean0 = acc_bias.mean
      local mean1 = mean0 + (accel - mean0) / acc_bias.count
      acc_bias.mean = mean1
      -- Independent variances
      for i, w in ipairs(accel) do
        acc_bias.variance[i] = acc_bias.variance[i] + (w - mean0[i]) * (w - mean1[i])
      end
    end
  elseif ENABLE_AUTO_BIAS and (acc_bias.count == 300) then
    acc_bias.variance = acc_bias.variance / (acc_bias.count - 1)
    gyro_bias.variance = gyro_bias.variance / (gyro_bias.count - 1)
    ENABLE_AUTO_BIAS = false
  end

  gyro[1] = gyro[1] - gyro_bias.mean[1]
  gyro[2] = gyro[2] - gyro_bias.mean[2]
  gyro[3] = gyro[3] - gyro_bias.mean[3]

  accel = accel * 0.25 + 0.75 * (accel_last or accel)
  accel_last = accel

  -- SLAM
  if dt_imu < 0.20 then
    ukf:motion_gyro(gyro, dt_imu)
    local gNorm = vnorm(accel)
    local gNormErr = math.abs(gNorm - 1)
    if gNormErr <= 0.06 then
      -- TODO: Give a unit vector with noise filtering
      accel = vunit(accel)
      ukf:correct_gravity(accel)
    else
      print("Jerk", gNorm, accel)
      -- ukf:correct_gravity(accel)
    end
    slam.update_gyro(unpack(gyro * dt_imu))
  end

  -- The roll/pitch estimates are not great
  -- rbt0_to_rbt = tf.from_rpy_trans({rpy[1], rpy[2], 0})

  if realtime then
    log_announce(false, {
      dt = dt_imu,
      rpy = quaternion.to_rpy(q_imu and q_imu or ukf.orientation),
      accel = accel,
      gyro = gyro,
      q_ukf = ukf.orientation,
    }, "inertial")
  end

end

----------- Laser -----------
local d2p = require'hokuyo'.distances2points
local lsr_to_rbt0 = tf.trans(0.28, 0, 0.115)

function update.hokuyo(obj)
  local lsr_to_rbt = rbt0_to_rbt * lsr_to_rbt0
  -- Find the points in the frame of the hokuyo
  local xs_hok, ys_hok, zs_hok, hits = d2p(obj.distances)
  local intensities = {}
  for i,int in ipairs(obj.intensities or hits) do
    intensities[i] = hits[i] and int or 0
  end
  -- Find the points in the frame of the robot
  -- NOTE: Weird rotations going on here...
  local pts_rbt = tf.batch_mul(
    lsr_to_rbt, {xs_hok, ys_hok, zs_hok})
  -- Now, ask SLAM to use the valid points
  slam.update_laser(pts_rbt, hits)

  if realtime then
    log_announce(false, {pts=pts_rbt, int=intensities}, 'point_cloud_hokuyo')
  end
end

----------- Motor Controller -----------
local last_tach_t, last_tach = false, 0

function update.vesc(obj, t_us)
  local dt_tach = tonumber(t_us - (last_tach_t or t_us)) / 1e6
  last_tach_t = t_us
  -- Remap
  local tach = -1 * obj.tach
  --
  local d_tach = tach - (last_tach or 0)
  last_tach = tach
  -- Kill off values that had too much time in b/t
  if dt_tach < 0.15 then
    local TACH_FACTOR = 8 -- No idea why this factor...
    local dx_odom = d_tach * dt_tach / TACH_FACTOR
    slam.update_odometry(dx_odom)
  end
end

-- Send the map every second
local dt_send = 1e6
local dt_save = 0
local function run_update(dt0_log)
  local dt = dt0_log - dt_save
    if dt < dt_send then return end
  dt_save = dt0_log
  print(string.format(
    "SLAM | %d seconds", dt0_log/1e6))
  local pose_x, pose_y, pose_th = slam.get_pose()
  local pkt = {
    t = tonumber(t_us),
    pose = {pose_x, pose_y, pose_th}
  }
  if has_png then
    local map_info = slam.map.map_info
    local t0 = time()
    pkt.png = png.compress(unpack(map_info))
    local t1 = time()
    print(string.format("%.2f ms | %.2f ratio -> %d bytes",
      (t1-t0)*1e3, #pkt.png / map_info[2], #pkt.png))
  end

  if realtime then log_announce(false, pkt, 'slam') end
  -- map.save_pgm(string.format("/tmp/map%03d.pgm", dt0_log/1e6))
end

-- Actually play the log
racecar.play(fnames, realtime, update, run_update)

if has_png then
  local map_info = slam.map.map_info
  local t0 = time()
  local png_str = assert(png.compress(unpack(map_info)))
  local t1 = time()
  print(string.format("%.2f ms | %.2f ratio",
    (t1-t0)*1e3, #png_str / slam.map.map_info[2]))
  io.open("/tmp/map.png", "w"):write(png_str):close()
end
