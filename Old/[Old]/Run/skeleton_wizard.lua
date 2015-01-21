dofile'../include.lua'
local libSkeleton = require'libSkeleton'
local log_file = '../Logs/dummy_skeleton.log'
-- How to communicate data?
local use_body = true
local use_zmq = false
local use_udp = false

-- Libraries
require'unix'
local util = require'util'
local quaternion = require'quaternion'
local mp = require'msgpack'

-- Functions for transmitting the data
local function broadcast_skeleton_zmq(metadata,enc_jnts1,enc_jnts2)
  local packed_metadata = mp.pack(metadata)
	skeleton_ch1:send({packed_metadata,enc_jnts1})
	skeleton_ch2:send({packed_metadata,enc_jnts2})
end

local function broadcast_skeleton_udp(metadata,enc_jnts1,enc_jnts2)
	local packed_joints = mp.pack({meta=metadata,raw=enc_jnts1})
	udp_skeleton1:send( packed_joints )
	local packed_joints = mp.pack({meta=metadata,raw=enc_jnts2})
	udp_skeleton2:send( packed_joints )
end

-- Set up the UDP sending
if use_zmq then
  udp = require'udp'
  udp_skeleton1 = udp.new_sender('localhost',43234)
  udp_skeleton2 = udp.new_sender('localhost',43235)
end

-- Set up the ZMQ sending
if use_zmq then
  simple_ipc = require'simple_ipc'
  skeleton_ch1 = simple_ipc.new_publisher('skeleton1')
  skeleton_ch2 = simple_ipc.new_publisher('skeleton2')
end

if use_body then
  Body = require'Body'
end

-- Start the Skeleton system
--libSkeleton.entry( log_file )
libSkeleton.entry()

-- Set up timing debugging
local cnt = 0;
local t_last = unix.time()
local t_debug = .5

-- Start loop
local q = quaternion.new()
local left_shoulder_rpy = vector.zeros(3)
while true do
	
	-- Update the skeleton
  local visible_users = libSkeleton.update()
	
	-- Check the time of acquisition
	local t = unix.time()
  
  -- Directly use the body to change the robot's joint
  -- Debug
  local user2 = libSkeleton.get_joint_table(2)
  if use_body then
    local qLArm, qRArm = libSkeleton.get_thorop_arm_angles(2)
    if user2[1] then
      q = quaternion.new( user2[3].orientation )
      left_shoulder_rpy = quaternion.to_rpy(q)
      left_shoulder_rpy = vector.new({left_shoulder_rpy[2],left_shoulder_rpy[3],left_shoulder_rpy[1]})
      left_shoulder_rpy = left_shoulder_rpy+vector.new({math.pi/2,-math.pi/2,0})
      Body.set_larm_command_position({
        left_shoulder_rpy[2],
        left_shoulder_rpy[3],
        left_shoulder_rpy[1],
        0,
        0,
        0
        })
      left_shoulder_rpy = left_shoulder_rpy*180/math.pi
      end
  end

  
  -- Broadcast data
  if use_zmq or use_udp then
    -- Save the metadata
    local metadata = {}
    metadata.t = t
    -- Pack the positions data
    local enc_jnts1 = nil
    local enc_jnts2 = nil
  	if visible[1] then enc_jnts1 = pack_positions(1) end
  	if visible[2] then enc_jnts2 = pack_positions(2) end
    if use_zmq then broadcast_skeleton_zmq(metadata,enc_jnts1,enc_jnts2) end
    if use_udp then broadcast_skeleton_udp(metadata,enc_jnts1,enc_jnts2) end
  end
	
	-- Debug the timing
  cnt = cnt+1
  if t-t_last>t_debug then
    os.execute('clear')
    local msg = string.format("%.2f FPS.  Tracking", cnt/t_debug)
		if visible_users[1] then msg = msg..' User 1' end
		if visible_users[2] then msg = msg..' User 2' end
    io.write("Skeleton Wizard | ",msg,'\n\n')
		io.flush()
    
    if user2[1] then 
      print()
      print('Left Shoulder pitch (1st joint on THOR-OP)')
      print(left_shoulder_rpy[1])
      print('Left Shoulder roll (2nd joint on THOR-OP)')
      print(left_shoulder_rpy[2])
      print('Left Shoulder yaw (3rd joint on THOR-OP)')
      print(left_shoulder_rpy[3])
    end
    
    t_last = t
    cnt = 0
  end
	
end