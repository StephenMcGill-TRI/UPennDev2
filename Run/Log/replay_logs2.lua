module(... or '', package.seeall)

-- Add the required paths
uname  = io.popen('uname -s')
system = uname:read();
cwd = '.';
package.cpath = cwd.."/../Lib/?.so;"..package.cpath;
package.path = cwd.."/../Util/?.lua;"..package.path;
package.path = cwd.."/../Vision/?.lua;"..package.path;

local serialization = require 'serialization'
local util = require 'util'
require 'cutil'

-- Data Type specific
local dataPath = '~/shadwell/day2_third/logs/';
local dataStamp = '02.27.2013';
local dataTypes = {'lidar','arduimu','uvc'}
local dataTypes = {'lidar','arduimu'}
local realtime = true;
require 'rcm'
local unix = require 'unix'

-- Get the list of log files
function get_log_file_list()
  local log_file_list_iter = {};
  for i=1,#dataTypes do
    local log_file = dataTypes[i]..dataStamp..'*'
    local tmp_file_list = 
    assert(io.popen('/bin/ls '..dataPath..'/'..log_file, 'r'));
    log_file_list_iter[i] = tmp_file_list:lines();
  end
  return log_file_list_iter;
end

-- Parse the name from a lidar entry
-- Lua log specific
function parse_name(namestr)
  local name = {}
  name.str = namestr:sub(1,namestr:find("%p")-1);
  namestr = namestr:sub( namestr:find('%p')+1 );
  name.counter = tonumber( namestr:sub( 1,namestr:find("%p")-1) );
  namestr = namestr:sub(namestr:find("%p")+1);
  name.partnum = tonumber(namestr:sub(1,namestr:find("%p")-1) )
  namestr = namestr:sub(namestr:find("%p")+1);
  name.parts = tonumber(namestr);
  return name;
end

-- Parse the data
-- Specific to each dataType
local parsers_tbl = {}
parsers_tbl[1] = function ( str )
  local lidar_data = serialization.deserialize( str );
  local lidar_tbl = {};
  if lidar_data.arr then
    -- Grab the counter of this lidar scan
    local name = parse_name( lidar_data.arr.name );
    lidar_tbl.counter = name.counter;
    -- Put the ranges into a userdata
    -- TODO: FFI this
    local lidar_ranges = cutil.test_array();
    cutil.string2userdata(lidar_ranges, lidar_data.arr.data);
    lidar_tbl.ranges = lidar_ranges;
    -- Store the timestamp of the data
    lidar_tbl.t = lidar_data.t;
  else
    return nil;
  end
  return lidar_tbl;
end
-- IMU Parser
parsers_tbl[2] = function ( str )
  return serialization.deserialize( str );
end

local pushers_tbl = {}
pushers_tbl[1] = function ( lidar_tbl )
  rcm.set_lidar_timestamp(lidar_tbl.t);
  rcm.set_lidar_ranges( lidar_tbl.ranges );
  rcm.set_lidar_counter(lidar_tbl.counter);
end
pushers_tbl[2] = function ( imu_tbl )
  rcm.set_imu_timestamp( imu_tbl.t );
  rcm.set_imu_acc( {imu_tbl.Ax, imu_tbl.Ay, imu_tbl.Az} );
  rcm.set_imu_gyro( {imu_tbl.Wx, imu_tbl.Wy, imu_tbl.Wz} );
  rcm.set_imu_rpy( {imu_tbl.R, imu_tbl.P, imu_tbl.Y} );
end

function open_log_file( d )
  -- Use a Global variable.  Assume it is defined
  local log_file_name = log_file_iters[d]()
  if not log_file_name then
    return false
  end
  local log_f_handle = assert(io.open(log_file_name, 'r+'));
  -- Update global variabels
  log_handles[d] = log_f_handle;
  entry_iters[d] = log_f_handle:lines()
  return true;
end


-- Initialize Global Variables
entry_iters = {};
-- Save the log handles
log_handles = {};
-- Save the latest entry
latest_entry_tbls = {};
-- Set the Log file List
log_file_iters = get_log_file_list();

-- Initial Opening
for i=1,#log_file_iters do
  print('Opening a new '..dataTypes[i]..' file...')
  open_log_file( i );
  latest_entry_tbls[i] = nil;
end

-- Loop until we say to stop
local last_ts = nil;
local entry_timestamps = {}
while true do
  --for trials=1,50 do
  -- Read in datatypes that have not been loaded
  for d=1,#dataTypes do
    -- Only update the blank entries
    if latest_entry_tbls[d]==nil then
      local entry_str = entry_iters[d]();
      if entry_str then
        --print('Entry:',entry_str)
        latest_entry_tbls[d] = parsers_tbl[d]( entry_str )
      else
        log_handles[d]:close()
        print('Opening a new '..dataTypes[d]..' file...')
        local file_status = open_log_file( d );
        if file_status==false then
          entry_str = nil;
        else
          entry_str = entry_iters[d]();
        end
        if not entry_str then
          print('Done with the '..dataTypes[d]..' logs.')
          latest_entry_tbls[d] = {};
          latest_entry_tbls[d].t = nil;
        else
          latest_entry_tbls[d] = parsers_tbl[d]( entry_str )
        end
      end
      -- Store the timestamps, so we can search easily
      entry_timestamps[d] = latest_entry_tbls[d].t;
    end
  end

  -- Who has the min timestamp?
  local min_ts, d_idx = util.min(entry_timestamps)

  if not dataTypes[d_idx] then
    print('Done all logs!')
    return
  end

  -- Push this entry to SHM
  local t_diff = min_ts - (last_ts or min_ts);
  last_ts = min_ts;

  -- Specific to day2_third
  -- TODO: generalize with table
  if( min_ts<1361997212.4557 ) then
    realtime = false;
  else
    realtime = true;
  end

  -- If we wish to run in realtime, then sleep accordingly
  if realtime then
    unix.usleep( 1e6*t_diff );
  end
--  print('Pushing',d_idx,dataTypes[d_idx], min_ts)
--  print('ts:',entry_timestamps[1],entry_timestamps[2]);
  pushers_tbl[d_idx]( latest_entry_tbls[d_idx] )
  -- Empty the data structure
  latest_entry_tbls[d_idx]=nil
end
