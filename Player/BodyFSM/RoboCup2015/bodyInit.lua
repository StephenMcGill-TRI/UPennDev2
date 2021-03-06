local state = {}
state._NAME = ...

local Body = require'Body'
local t_entry, t_update, t_exit

function state.entry()
  print(state._NAME..' Entry' )

  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry

  -- Initialize all other state machines
  motion_ch:send'stand'
  head_ch:send'init'

end

function state.update()
  --  print(state._NAME..' Update' ) 
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --TODO: Check whether all FSMs have done initialzing 
  local body_init = mcm.get_status_body_init()
  if body_init==1  then return "done" end
end

function state.exit()
  --Release velocity limits for all the servos here


  if not IS_WEBOTS then
    for i=1,10 do
--      Body.set_head_command_velocity({6000,6000})
      Body.set_head_command_velocity({6000,6000})
      unix.usleep(1e6*0.01);

      Body.set_waist_command_velocity({0,0})
      unix.usleep(1e6*0.01);

        Body.set_larm_command_velocity({0,0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_rarm_command_velocity({0,0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_larm_command_acceleration({0,0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_rarm_command_acceleration({0,0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_lleg_command_velocity({0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_rleg_command_velocity({0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_rleg_command_acceleration({0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

        Body.set_lleg_command_acceleration({0,0,0,0,0,0})
        unix.usleep(1e6*0.01);

  --SJ: this somehow locks down head movement!!!!!!!!
        Body.set_head_position_p({pg,pg})
        unix.usleep(1e6*0.01);

        Body.set_rleg_position_p({pg,pg,pg,pg,pg,ag})
        unix.usleep(1e6*0.01);

        Body.set_lleg_position_p({pg,pg,pg,pg,pg,ag})
        unix.usleep(1e6*0.01);


        Body.set_lleg_torque_enable(1)
        unix.usleep(1e6*0.01);

        Body.set_rleg_torque_enable(1)
        unix.usleep(1e6*0.01);

        Body.set_lleg_torque_enable(1)
        unix.usleep(1e6*0.01);

        Body.set_rleg_torque_enable(1)
        unix.usleep(1e6*0.01);

        Body.set_waist_torque_enable(1)
        unix.usleep(1e6*0.01);

        Body.set_head_torque_enable(1)
        unix.usleep(1e6*0.01);


    end
  end

  hcm.set_step_stepcount(1)
  print(state._NAME..' Exit' )
  t_exit = Body.get_time()
end

return state
