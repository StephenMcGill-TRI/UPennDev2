cwd = os.getenv('PWD')
require('init')

require 'gcm'
teamID   = gcm.get_team_number();
playerID = gcm.get_team_player_id();
nPlayers = gcm.get_game_nplayers();

-- For testing
nPlayers = 2;

-- run from log file (this is set automatically)
-- lua run_prime X.lua, Y.lua, Z.lua, ... 
-- where X,Y,Z,... are the log files for users 1,2,3,...
logs = false;
inp_logs = {};
-- box runs punch detection code
print("Num args: ",#arg)
if( arg[1] ) then
  logs = true
  nPlayers = #arg
  for i=1,nPlayers do
    dofile( arg[i] )
    inp_logs[i] = log;
  end
else
  require 'primesense'  
end

-- Enable Webots specific
if (string.find(Config.platform.name,'Webots')) then
  print('On webots!')
  webots = true;
else
  print('Real robot!')
end

-- Enable the network
net = true;
if( webots ) then
  net = false;
end

-- Require the primecm modules
pc = {};
for i=1,nPlayers do
  pc[i] = require('primecm'..i)
end

-- Issue debug line telling which mode we are in
print '\n\n=====================';
print('Run Logs?',logs);
print('Team/Player',teamID..'/'..playerID);
print('nPlayers',nPlayers);
print '=====================';

t0 = unix.time();
timestamp0 = t0;
t_init = 0;
if( logs ) then
  n_logs = table.getn(log);
  local it = 1;
  timestamp0 = log[it].t;
  it = it+1;
  while(not timestamp0) do
    timestamp0 = log[it].t;
    it = it+1;
  end
end

print(Config.dev.team..' entry...')
io:flush()

if( net ) then
  require 'Team'
  Team.entry(true) -- true means we have the primesense
end

print('Entering Loop...')
io:flush()

count = 0;
init = false;
while( not logs or count<n_logs ) do
  count = count + 1;
  if( not logs ) then
    ret = primesense.update_joints();
    timestamp = unix.time();
  else
    if( timestamp and log[count].t<timestamp ) then
      timestamp0 = log[count].t;
    end
    timestamp = log[count].t;
  end
  t_start = unix.time();
  if( logs or ret ) then
    if( not init and not logs ) then
      init = true;
      timestamp0 = timestamp;
    end

    --[[
    -- Left person is always player 1
    -- so that we don't switch in the middle of the program
    center = {};
    for pl=1,nPlayers do
      -- Get the torso stats
      local pos, rot, confidence, active = primesense.get_jointtables(pl,3);
      if( active ) then
        center[pl] = pos;
      end
    end
    -- Match to closest centroid of before
    if( prev_center and #center>0 ) then -- We have context
      for pl=1,nPlayers do
        if(center[pl]) then -- Match the found center with one from before
          -- Just sort the differences...
          diffs = center[pl] - prev_center;

        end
      end
    else
      prev_center = {}
      for pl=1,nPlayers do
        if(center[pl]) then
          prev_center[pl] = center[pl];
        end
      end
    end
    --]]

    -- Check each player
    -- Is each player active?
    for i,v in ipairs(pc[playerID].jointNames) do
      if( logs ) then
        for pl=1,nPlayers do
          log = inp_logs[pl];
          pos = { log[count].x[i],log[count].y[i],log[count].z[i] };
          confidence = { log[count].posconf[i],log[count].rotconf[i] };
          primecm = pc[pl];
          primecm['set_position_'..v]( pos );
          primecm['set_confidence_'..v]( confidence );
          primecm.set_skeleton_found( 1 );
          primecm.set_skeleton_timestamp( timestamp-timestamp0 );
        end
      else
        -- Multiple players
        for pl=1,nPlayers do
          pos, rot, confidence, active = primesense.get_jointtables(pl,i);
          pos = vector.new(pos)/1000;
          primecm = pc[pl];
          primecm['set_position_'..v]( pos );
          primecm['set_orientation_'..v]( rot );
          primecm['set_confidence_'..v]( confidence );
          primecm.set_skeleton_found( active );
          primecm.set_skeleton_timestamp( timestamp-timestamp0 );
        end
      end
    end
  end

  -- Update the Team information
  if( net ) then
    Team.update()
  end

  --[[
  -- Done running
  local byte = get_key_byte();
  if( byte==string.byte('e') ) then
  primecm.set_skeleton_enabled( 1-primecm.get_skeleton_enabled() );
  end
  if(byte==string.byte('q')) then
  break;
  end
  --]]

  -- Timing
  if( init and not logs ) then
    if( count % 60==0 ) then
      local fps = 60 / (unix.time()-(t_count or 0))
      t_count = unix.time();
      print('FPS: ',fps)
      print('Time',timestamp-timestamp0 );
      print('User 1: ', pc[1]['get_skeleton_found']());
      print('User 2: ', pc[2]['get_skeleton_found']());
      print();
    end
  end
  if(logs and count<n_logs) then
    if( count % 60==0 ) then
      print('Count:',count,'Time:',timestamp );    
    end
    local timestamp_next = log[count+1].t;
    local twait = timestamp_next-timestamp;
    local t_loop = unix.time() - t_start;
    unix.usleep( 1e6*math.max(twait-t_loop,0) );
  end

end
-- After done playing, reset the skeleton found variable so no more movement
print('Finished!')
primecm.set_skeleton_found( {0,0} );
if( net ) then
  Team.update();
end

