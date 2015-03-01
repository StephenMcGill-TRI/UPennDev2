local state = {}
state._NAME = ...
local vector = require'vector'

local Body = require'Body'
local t_entry, t_update, t_finish

require'mcm'

require'dcm'

local qLArm, qRArm


local larm_pos_old,rarm_pos_old
local lleg_pos_old,rleg_pos_old
local larm_vel_old,rarm_vel_old
local lleg_vel_old,rleg_vel_old

local l_comp_torque,r_comp_torque

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry
  t_finish = t

--
  
  
--  Body.set_larm_torque_enable({1,1,1, 1,1,1,1}) --enable force control
  Body.set_rarm_torque_enable({1,1,1, 1,1,1,1}) --enable force control

  Body.set_larm_torque_enable({2,2,2, 2,2,2,2}) --enable force control

    Body.set_larm_torque_enable({2,1,1, 1,1,1,1}) --enable force control
 Body.set_larm_torque_enable({2,2,2, 2,2,2,2}) --enable force control

  Body.set_lleg_torque_enable({1,1,1, 1,1,1}) --enable force control
  Body.set_rleg_torque_enable({1,1,1, 1,1,1}) --enable force control

--  Body.set_lleg_torque_enable({1,1,2,2,2,1}) --enable force control
--  Body.set_rleg_torque_enable({1,1,2,2,2,1}) --enable force control


  larm_pos_old = Body.get_larm_position()  
  rarm_pos_old = Body.get_rarm_position()
  lleg_pos_old = Body.get_lleg_position()
  rleg_pos_old = Body.get_rleg_position()

  larm_vel_old = vector.zeros(7)
  rarm_vel_old = vector.zeros(7)
  lleg_vel_old = vector.zeros(6)
  rleg_vel_old = vector.zeros(6)

  l_comp_torque = vector.zeros(7)
  r_comp_torque = vector.zeros(7)

  

end

local count=0

function state.update()
--  print(state._NAME..' Update' )
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --if t-t_entry > timeout then return'timeout' end


  

--calculate theoretial weight distribution between two feet
--assuming zero ankle torque 


count=count+1

    local rpy_angle = Body.get_rpy()

    local lleg_cmdpos = Body.get_lleg_command_position()
    local rleg_cmdpos = Body.get_rleg_command_position()
    local lleg_pos = Body.get_lleg_position()
    local rleg_pos = Body.get_rleg_position()


    local lleg_actual_torque = Body.get_lleg_current()
    local rleg_actual_torque = Body.get_rleg_current()
    local lft = mcm.get_status_LFT()
    local rft = mcm.get_status_RFT()


    local qWaist = Body.get_waist_command_position()
    local qLArm = Body.get_larm_command_position()
    local qRArm = Body.get_rarm_command_position()



    local uTorso = mcm.get_status_uTorso()
    local uLeft = mcm.get_status_uLeft()
    local uRight = mcm.get_status_uRight()

    --TODO: find the shortest distance point from uTorso
    local uTorsoLeft= util.pose_relative(uLeft,uTorso)
    local uTorsoRight= util.pose_relative(uRight,uTorso)
    local leftDist,rightDist =  uTorsoLeft[2],-uTorsoRight[2]

--[[
    
    local com_legless=Body.Kinematics.calculate_com_pos2(qWaist,qLArm,qRArm,lleg_pos,rleg_pos,0,0,0,  0,0)
    print("upper body com offset:",com_legless[1]/com_legless[4])
    local com_leg=Body.Kinematics.calculate_com_pos2(qWaist,qLArm,qRArm,lleg_pos,rleg_pos,0,0,0,  1,1)
    print("whole body com offset:",com_leg[1]/com_leg[4])
--]]


--[[

    local com_whole_body=Body.Kinematics.calculate_com_pos2(qWaist,qLArm,qRArm,lleg_pos,rleg_pos,0,0,0,  1,1)
    local force_left = (rightDist/(leftDist+rightDist))*com_whole_body[4]*9.81
    local force_right = (leftDist/(leftDist+rightDist))*com_whole_body[4]*9.81



  local lleg_vel =  (lleg_pos-lleg_pos_old)/dt
  local rleg_vel =  (rleg_pos-rleg_pos_old)/dt  
  local lleg_pos_err = (lleg_cmdpos-lleg_pos)
  local rleg_pos_err = (rleg_cmdpos-rleg_pos)
  lleg_pos_old,rleg_pos_old = lleg_pos,rleg_pos

  local acc_factor = {0.5,0.5,50,  50,10,0.03}
  local lleg_comp_acc = util.pid_feedback(lleg_pos_err, lleg_vel, dt,acc_factor)
  local rleg_comp_acc = util.pid_feedback(rleg_pos_err, rleg_vel, dt,acc_factor)    


  local lleg_torque = vector.new(Body.Kinematics.calculate_leg_torque(
      rpy_angle,lleg_pos,lleg_comp_acc, 1,lft[1] , {-uTorsoLeft[1],0,0}   ))
  local rleg_torque = vector.new(Body.Kinematics.calculate_leg_torque(
      rpy_angle,rleg_pos,rleg_comp_acc, 0,rft[1] , {-uTorsoLeft[1],0,0}   ))

  Body.set_lleg_command_torque(lleg_torque)
  Body.set_rleg_command_torque(rleg_torque)




  if count%300==0 then

    print(string.format("Roll: %.1f Pitch:%.1f",rpy_angle[1],rpy_angle[2]))

    print("calculated forces: ",force_left,force_right)
    print("measured forces: ",lft[1],rft[1])


    print(string.format("LLeg position error: %.3f %.3f/ %.3f %.3f %.3f / %.3f",
        unpack(lleg_pos_err*180/math.pi)))


    print("Support:",-uTorsoLeft[1])

    print("COM xy:",-uTorsoLeft[1])




    print(string.format("LLeg actual torque: %.3f %.3f/ %.3f %.3f %.3f / %.3f",
        unpack(lleg_actual_torque)))
    

    print(string.format("LLeg calced torque: %.2f %.2f/ %.2f %.2f %.2f / %.3f",
        unpack(lleg_stall_torque)))

    print(string.format("RLeg actual torque: %.3f %.3f/ %.3f %.3f %.3f / %.3f",
        unpack(rleg_actual_torque)))
    print(string.format("RLeg calced torque: %.3f %.3f/ %.3f %.3f %.3f / %.3f",
        unpack(rleg_stall_torque)))
end
--]]  

--
----------------------------------------------------------------------------
-- Arm force-control code #1

  local larm_cmdpos = Body.get_larm_command_position()
  local rarm_cmdpos = Body.get_rarm_command_position()

  local larm_pos = Body.get_larm_position()
  local rarm_pos = Body.get_rarm_position()

--  l_stall_torque = Body.Kinematics.calculate_arm_torque(larm_pos)
--  r_stall_torque = Body.Kinematics.calculate_arm_torque(rarm_pos)

  local larm_vel =  (larm_pos-larm_pos_old)/dt
  local rarm_vel =  (rarm_pos-rarm_pos_old)/dt

  local larm_acc = (larm_vel-larm_vel_old)/dt
  local rarm_acc = (rarm_vel-rarm_vel_old)/dt

  larm_pos_old,rarm_pos_old = larm_pos,rarm_pos
  larm_vel_old,rarm_vel_old = larm_vel,rarm_vel

  local larm_pos_err = (larm_cmdpos-larm_pos)
  local rarm_pos_err = (rarm_cmdpos-rarm_pos)

--  local torque_factor = {1,1,1,1,0.2,0.05,0.03}
  --local accel_factor = {0.5,0.5,0.5,0.5,0.1,0.05,0.03}
  local accel_factor = vector.ones(7)*1



  local l_comp_acc = vector.new(util.pid_feedback(larm_pos_err, larm_vel, dt, accel_factor, count%125==0))
  local r_comp_acc = vector.new(util.pid_feedback(rarm_pos_err, rarm_vel, dt, accel_factor))

  local l_torques = Body.Kinematics.calculate_arm_torque(rpy_angle,larm_pos,l_comp_acc)
  local l_stall_torque = vector.new(l_torques.stall);
  local l_acc_torque = vector.new(l_torques.acc);
  
  local l_torques = Body.Kinematics.calculate_arm_torque(rpy_angle,larm_pos,l_comp_acc)
  local r_torques = Body.Kinematics.calculate_arm_torque(rpy_angle,rarm_pos,r_comp_acc)

  local l_stall_torque = vector.new(l_torques.stall);
  local r_stall_torque = vector.new(r_torques.stall);
  local l_acc_torque = vector.new(l_torques.acc)*5;
  local r_acc_torque = vector.new(r_torques.acc)*5;

  Body.set_larm_command_torque(l_stall_torque+l_acc_torque)
  Body.set_rarm_command_torque(r_stall_torque+r_acc_torque)



  local larm_actual_torque = Body.get_larm_current()
  local rarm_actual_torque = Body.get_rarm_current()

  if count%125==0 then
    print(string.format("LArm actual torque: %.3f %.3f %.3f/ %.3f / %.3f %.3f %.3f",
          unpack(larm_actual_torque)))
    print(string.format("LArm stall torque: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",
          unpack(l_stall_torque)))
    print(string.format("LArm position err: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",
          unpack(larm_pos_err*180/math.pi) ))
    print(string.format("LArm target   acc: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",      
          unpack(l_comp_acc*180/math.pi) ))
    print(string.format("LArm  rad tgt acc: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",
          unpack(l_comp_acc) ))    


    print(string.format("LArm actual   vel: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",
          unpack(larm_vel*180/math.pi) ))

    print(string.format("LArm actual   acc: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f",
          unpack(larm_acc*180/math.pi) ))

    
    print(string.format("LArm accel torque: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f\n",
          unpack(l_acc_torque)))

--[[
    print(string.format("RArm actual torque: %.2f %.2f %.2f/ %.2f / %.3f %.3f %.3f",
          unpack(rarm_actual_torque)))
    print(string.format("RArm calc torque: %.2f %.2f %.2f/  %.2f /%.3f %.3f %.3f",
          unpack(r_stall_torque)))
    print(string.format("RArm accel torque: %.3f %.3f %.3f/ %.3f /%.3f %.3f %.3f\n",
          unpack(r_acc_torque)))
--]]


  end

----------------------------------------------------------------------------
--


end

function state.exit()
  print(state._NAME..' Exit' )
end

return state
