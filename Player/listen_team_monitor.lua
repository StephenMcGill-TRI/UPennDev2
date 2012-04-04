module(... or '', package.seeall)


-- Add the required paths
cwd = '.';
computer = os.getenv('COMPUTER') or "";
if (string.find(computer, "Darwin")) then
   -- MacOS X uses .dylib:                                                      
   package.cpath = cwd.."/Lib/?.dylib;"..package.cpath;
else
   package.cpath = cwd.."/Lib/?.so;"..package.cpath;
end
package.path = cwd.."/Util/?.lua;"..package.path;
package.path = cwd.."/Config/?.lua;"..package.path;
package.path = cwd.."/Lib/?.lua;"..package.path;
package.path = cwd.."/Dev/?.lua;"..package.path;
package.path = cwd.."/World/?.lua;"..package.path;
package.path = cwd.."/Vision/?.lua;"..package.path;
package.path = cwd.."/Motion/?.lua;"..package.path; 


require ('Config')
require ('cutil')
require ('vector')
require ('serialization')
require ('Comm')
require ('util')
require ('wcm')
require ('gcm')
require ('vcm')
require 'unix'

Comm.init(Config.dev.ip_wireless,54321);
print('Receiving Team Message From',Config.dev.ip_wireless);
teamNumber = Config.game.teamNumber;


function push_team_struct(obj)
--  wcm.set_teamdata_id(obj.id);
  states={};

  states.teamColor=wcm.get_teamdata_teamColor();
  states.robotId=wcm.get_teamdata_robotId();
  states.role=wcm.get_teamdata_role();
  states.time=wcm.get_teamdata_time();
  states.posex=wcm.get_teamdata_posex();
  states.posey=wcm.get_teamdata_posey();
  states.posea=wcm.get_teamdata_posea();
  states.ballx=wcm.get_teamdata_ballx();
  states.bally=wcm.get_teamdata_bally();
  states.ballt=wcm.get_teamdata_ballt();
  states.attackBearing=wcm.get_teamdata_attackBearing();
  states.fall=wcm.get_teamdata_fall();
  states.penalty=wcm.get_teamdata_penalty();
  states.battery_level=wcm.get_teamdata_battery_level();

  states.goal=wcm.get_teamdata_();
  states.goalv11=wcm.get_teamdata_goalv11();
  states.goalv11=wcm.get_teamdata_goalv11();
  states.goalv11=wcm.get_teamdata_goalv11();
  states.goalv11=wcm.get_teamdata_goalv11();
  states.landmark=wcm.get_teamdata_landmark();
  states.landmarkv1=wcm.get_teamdata_landmarkv1();
  states.landmarkv2=wcm.get_teamdata_landmarkv2();

--print("Team message from",obj.id)
  id=obj.id;
--states.role[id]=obj.id; --robot id?
  states.teamColor[id]=obj.teamColor;
  states.robotId[id]=obj.id;
  states.role[id]=obj.role;
  states.time[id]=obj.time;
  states.posex[id]=obj.pose.x;
  states.posey[id]=obj.pose.y;
  states.posea[id]=obj.pose.a;
  states.ballx[id]=obj.ball.x;
  states.bally[id]=obj.ball.y;
  states.ballt[id]=obj.ball.t;
  states.attackBearing[id]=obj.attackBearing;
  states.fall[id]=obj.fall;
  states.penalty[id]=obj.penalty;
  states.battery_level[id]=obj.battery_level;

  states.goal[id]=obj.goal;
  states.goalv11[id]=obj.goalv1[1];
  states.goalv12[id]=obj.goalv1[2];
  states.goalv21[id]=obj.goalv2[1];
  states.goalv22[id]=obj.goalv2[2];
  states.landmark[id]=obj.landmark;
  states.landmarkv1[id]=obj.landmarkv[1];
  states.landmarkv2[id]=obj.landmarkv[2];

--print("Ballx:",obj.ball.x);

  wcm.set_teamdata_teamColor(states.teamColor);
  wcm.set_teamdata_robotId(states.robotId);
  wcm.set_teamdata_role(states.role);
  wcm.set_teamdata_time(states.time)

  wcm.set_teamdata_posex(states.posex)
  wcm.set_teamdata_posey(states.posey)
  wcm.set_teamdata_posea(states.posea)
  wcm.set_teamdata_ballx(states.ballx)
  wcm.set_teamdata_bally(states.bally)
  wcm.set_teamdata_ballt(states.ballt)
  wcm.set_teamdata_attackBearing(states.attackBearing)
  wcm.set_teamdata_fall(states.fall)
  wcm.set_teamdata_penalty(states.penalty)
  wcm.set_teamdata_battery_level(states.battery_level)

  wcm.set_teamdata_goal(states.goal);
  wcm.set_teamdata_goalv11(states.goalv11);
  wcm.set_teamdata_goalv12(states.goalv12);
  wcm.set_teamdata_goalv21(states.goalv21);
  wcm.set_teamdata_goalv22(states.goalv22);

  wcm.set_teamdata_landmark(states.landmark);
  wcm.set_teamdata_landmarkv1(states.landmarkv1);
  wcm.set_teamdata_landmarkv2(states.landmarkv2);
end

while( true ) do
  while (Comm.size() > 0) do
    msg=Comm.receive();
    --print(msg)
    t = serialization.deserialize(msg);
    if (t and (t.teamNumber) and (t.teamNumber == teamNumber) and (t.id)) then
--      t.tReceive = Body.get_time();
      push_team_struct(t);
    end
  end
end
