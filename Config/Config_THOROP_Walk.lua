assert(Config, 'Need a pre-existing Config table!')
local vector = require'vector'

------------------------------------
-- Walk Parameters

local walk = {}

walk.init_command_velocity = 500
walk.init_command_accelleration = 50



walk.leg_p_gain = 64
walk.ankle_p_gain = 64

--Default-y vaue
walk.maxTurnSpeed = 0.10
walk.aTurnSpeed = 0.25
walk.maxStepCount = 8



print("Robot hostname:",HOSTNAME)

------------------------------------
-- Stance and velocity limit values
------------------------------------
walk.stanceLimitX = {-0.50,0.50}
--walk.stanceLimitY = {0.16,0.60}
walk.stanceLimitY = {0.16,0.30}
walk.stanceLimitA = {-10*math.pi/180,30*math.pi/180}

if IS_WEBOTS then

  walk.maxTurnSpeed = 0.20
  walk.aTurnSpeed = 0.2
  walk.maxStepCount = 12

  walk.foot_traj = 2; --square step

  --Robotis style walk
  walk.bodyHeight = 0.9285318
  walk.bodyTilt = 11*math.pi/180
  walk.footY = 0.1095
	walk.footX = 0
  walk.torsoX = 0.00    -- com-to-body-center offset

  walk.stepHeight = 0.04
  walk.supportX = 0.01
  walk.supportY = 0.03
  walk.tZMP = 0.28

  walk.tStep = 0.80
  walk.supportY = 0.03
  walk.tZMP = 0.28
  walk.phSingle = {0.15,0.85}
  walk.phZmp = {0.15,0.85}

  gyroFactorX = 490.23/(251000/180)*0
  gyroFactorY = 490.23/(251000/180)*0
  walk.ankleImuParamX={1, 0.9*gyroFactorX,  0*math.pi/180, 5*math.pi/180}
  walk.kneeImuParamX= {1, 0.3*gyroFactorX,    0*math.pi/180, 5*math.pi/180}
  walk.ankleImuParamY={1, 1.0*gyroFactorY,  0*math.pi/180, 5*math.pi/180}
  walk.hipImuParamY  ={1, 0.5*gyroFactorY,  0*math.pi/180, 5*math.pi/180}

  walk.hipRollCompensation = 1*math.pi/180
  walk.ankleRollCompensation = 1.2*math.pi/180
  walk.hipPitchCompensation = 0*math.pi/180
  walk.kneePitchCompensation = 0*math.pi/180
  walk.anklePitchCompensation = 0*math.pi/180
  walk.phComp = {0.1,0.9}
  walk.phCompSlope = 0.2


  walk.velLimitX = {-.05,.05}
  walk.velLimitY = {-.025,.025}
  walk.velLimitA = {-.2,.2}
  walk.velDelta  = {0.025,0.02,0.1}


  walk.stepHeight = 0.02--shorter step height
  walk.tZMP = 0.28

  --Webots-only params 
  walk.tZMP = 0.40 
  walk.footY = 0.09

else
------------------------------------
-- Stance parameters
------------------------------------

--Robotis default walk parameters
  walk.bodyHeight = 0.9285318
--  walk.supportX = 0.0515184
  walk.footY = 0.1095
  walk.footX = 0
  walk.bodyTilt = 11*math.pi/180
  walk.torsoX = 0.00    -- com-to-body-center offset

------------------------------------
-- Gait parameters
------------------------------------
  walk.tStep = 0.80
  walk.tZMP = 0.33
  walk.stepHeight = 0.04
  walk.phSingle = {0.15,0.85}
  walk.phZmp = {0.15,0.85}
  walk.supportX = 0.03
  walk.supportY = 0.04
------------------------------------
-- Compensation parameters
------------------------------------
  gyroFactorX = 490.23/(251000/180)*0.5
  gyroFactorY = 490.23/(251000/180)*0.5
  walk.ankleImuParamX={1, 0.9*gyroFactorX,  1*math.pi/180, 5*math.pi/180}
  walk.kneeImuParamX= {1, -0.3*gyroFactorX,  1*math.pi/180, 5*math.pi/180}
  walk.ankleImuParamY={1, 1.0*gyroFactorY,  1*math.pi/180, 5*math.pi/180}
  walk.hipImuParamY  ={1, 0.5*gyroFactorY,  2*math.pi/180, 5*math.pi/180}

  --Compensation testing values
  --[[
  walk.hipRollCompensation = 1*math.pi/180
  walk.ankleRollCompensation = 1.2*math.pi/180
  walk.hipPitchCompensation = -1.0*math.pi/180
  walk.kneePitchCompensation = 1.0*math.pi/180
  walk.anklePitchCompensation = 1.5*math.pi/180
  --]]

  walk.hipRollCompensation = 3*math.pi/180
  walk.ankleRollCompensation = 0*math.pi/180
  walk.hipPitchCompensation = 0*math.pi/180
  walk.kneePitchCompensation = 0*math.pi/180
  walk.anklePitchCompensation = 0*math.pi/180
  --
  walk.phComp = {0.1,0.9}
  walk.phCompSlope = 0.2


 ------------------------------------

  walk.foot_traj = 1; --curved step
  walk.foot_traj = 2; --square step

  --To get rid of drifting
  walk.velocityBias = {0.005,0,0}
  walk.velocityBias = {0.00,0,0}
  walk.velLimitX = {-.05,.05}
  walk.velLimitY = {-.02,.02}
  walk.velLimitA = {-.2,.2}
  walk.velDelta  = {0.025,0.02,0.1}
end


if HOSTNAME=="alvin" then
  walk.legBias =
    vector.new({
      0,  1.0,  -1.0,  -1.0,  0, 0, --LLEG
      0,  -0.50, 0,0,0, 0,  --RLEG
    })*DEG_TO_RAD

--New bias 12/14 9:12 PM

  walk.legBias =
    vector.new({
      0.875, 0.875, -0.625, -1.75, 0.00, -0.75,
      0.625, -0.50, 0.375, 0.125, 0.00, 0.125
    })*DEG_TO_RAD


--For alvin
  walk.hipRollCompensation = 1*math.pi/180
  walk.stepHeight = 0.03
  walk.supportX = 0.02
  walk.supportY = 0.03

  walk.velLimitY = {-.01,.01}
  walk.velLimitA = {-.2,.2}
  walk.velDelta  = {0.025,0.02,0.1}

--with battery
  walk.torsoX = -0.02


--Narrower stance, robotis value, 12/14 10:10PM
  walk.footY = 0.095
  walk.footX = 0
  walk.torsoX = -0.04
  walk.hipRollCompensation = 2*math.pi/180
  walk.hipRollCompensationLeft = 2*math.pi/180
  walk.hipRollCompensationRight = 2*math.pi/180

  walk.supportY = 0.05


  walk.velLimitA = {-.4,.4}

  --JK's bias 10:54PM
--hiproll: 1 -0.4325
--kneepitch: -2.155 -0.3475
--ankleroll: -0.345 1.0025

  walk.legBias =
    vector.new({
      0.875, 1, -0.625, -2.155, 0.00, -0.345,
      0.625, -0.4325, 0.375, -0.3475, 0.00, 1.0025
    })*DEG_TO_RAD

  --Faster turn testing
  walk.maxTurnSpeed = 0.20

  walk.maxTurnSpeed = 0.10

  walk.aTurnSpeed = 0.25
  walk.maxStepCount = 30


  --ankle roll tweak
  walk.legBias =
    vector.new({
      0.875, 1, -0.625, -2.155, 0.00, -0.615,
      0.625, -0.4325, 0.375, -0.3475, 0.00, 1.0025
    })*DEG_TO_RAD

  walk.torsoX3 = -0.04
  walk.torsoX = -0.02



--19th, 9:02AM
  walk.legBias =
    vector.new({
      0.875, 2.35, -0.625, -2.155,       0.00, -0.615,
      0.1525, -1.2425, 0.375, -0.3475,   0.00, 0.41
    })*DEG_TO_RAD


--D-day, 7:31AM

  walk.legBias =
    vector.new({
      0.875,  2.1475, -0.625, -1.5475,       0.00, -0.615,
      -0.2525, -1.58, 1.1175, -0.3475,   0.00, 0.41
    })*DEG_TO_RAD




--hiproll: 2.1475 -1.58
--hippitch: -0.625 1.1175
--kneepitch: -1.5475 -0.3475


--hipyaw:0.875 -0.2525

  walk.legBias =
    vector.new({
      0.875,  2.1475, -0.625, -1.5475,       1.2775, -0.615,
      -0.2525, -1.58, 1.1175, -0.3475,   0.940, 0.41
    })*DEG_TO_RAD



--AFTER HIP SWAP
--hiproll: 2.1475 -1.1075
--hippitch -0.8275 0.915
--kneepitch -1.9525 -0.7525

  walk.legBias =
    vector.new({
      0.875,  2.1475, -0.8275, -1.9525,       1.2775, -0.615,
      -0.2525, -1.1075, 0.915, -0.752,   0.940, 0.41
    })*DEG_TO_RAD

--angle fune tuning

  walk.legBias =
    vector.new({
      0.875,  2.1475, -0.49, -1.9525,       1.48, -0.615,
      -0.2525, -1.1075, 1.25, -0.752,   0.740, 0.41
    })*DEG_TO_RAD



elseif HOSTNAME=="teddy" then
--for teddy
  walk.hipRollCompensation = 1*math.pi/180
  walk.stepHeight = 0.03
  walk.supportX = 0.02
  walk.supportY = 0.03

  print("TEDDY")
  walk.legBias =
    vector.new({1, 0.50,    -0, -0.25,  0.25, 0.25,
                0, 0,    0.75,   -1,  0, -0.50,
    })*DEG_TO_RAD
--JK bias 12/14

  --hiproll 0.25 0.125
  --hippitch -0.25 0.375
  --kneepitch -0.5 -0.875

  walk.legBias =
    vector.new({1, 0.25,-0.25, -0.50,  0.25, 0.25,
                0, 0.125,0.375,-0.875,  0, -0.50,
    })*DEG_TO_RAD

--New values
  walk.footY = 0.095
  walk.footX = 0
  walk.torsoX = -0.04
  walk.hipRollCompensation = 2*math.pi/180

  walk.hipRollCompensationLeft = 2*math.pi/180
  walk.hipRollCompensationRight = 2*math.pi/180

  walk.supportY = 0.05

  walk.maxTurnSpeed = 0.20
  walk.aTurnSpeed = 0.25
  walk.maxStepCount = 30



--Little less torso shift (with hands on)
  walk.torsoX = -0.04
  walk.torsoX = -0.02

--ankle roll tweak
  walk.legBias =
    vector.new({1, 0.25,-0.25, -0.50,  0.25, 0.5875,
                0, 0.125,0.375,-0.875,  0, -0.7025,
    })*DEG_TO_RAD

--ankle pitch tweak
  walk.legBias =
    vector.new({1, 0.25,-0.25, -0.50,  0.52, 0.25,
                0, 0.125,0.375,-0.875,  0, -0.50,
    })*DEG_TO_RAD

--Support Y reduce
  walk.supportY = 0.05
  walk.supportY = 0.03

--ankle roll untweak

  walk.legBias =
    vector.new({1, 0.25,-0.25, -0.50,  0.52, 0.25,
                0, 0.125,0.375,-0.875,  0, -0.50,
    })*DEG_TO_RAD


--Roll fix after collapse

  walk.legBias =
    vector.new({1, 1.26,-0.25, -0.50,  1.06, 0.2475,
                0, -0.415,0.375,-0.875,  0, -0.50,
    })*DEG_TO_RAD










--DRC site, 12/18 3:21PM
--HY  1 -0.27
--HP -.495 1.455
--AP -0.4925 -0.945
--AR .01125 0.175

  walk.legBias =
    vector.new({1, 1.26,    0.495,   -0.50,  -0.4925, 0.1125,
            -0.27, -0.415,  1.455,   -0.875,  -0.945, 0.175,
    })*DEG_TO_RAD


  walk.torsoX = -0.02
  walk.torsoX = -0.00



  walk.supportY = 0.05
--Ankle tweak, 5:26PM
  walk.legBias =
    vector.new({1, 1.26,    0.495,   -0.50,  -0.02, 0.5175,
            -0.27, -0.415,  1.455,   -0.875,  -0.945, 0.175,
    })*DEG_TO_RAD



  walk.maxTurnSpeed = 0.10


else
  print("UNKNOWN ROBOT")
  walk.legBias =
    vector.new({0,0,0,0,0,0,
        0,0,0,0,0,0,
    })*DEG_TO_RAD
end










-----------------------------------------------------------
-- Stance parameters
-----------------------------------------------------------

local stance={}

--TEMPORARY HACK FOR PERCEPTION TESTING
--walk.bodyTilt = 0*math.pi/180

--Should we move torso back for compensation?
stance.enable_torso_compensation = 1
--stance.enable_torso_compensation = 0

stance.enable_sit = false
stance.enable_legs = true   -- centaur has no legs
stance.qWaist = vector.zeros(2)

stance.dqWaistLimit = 10*DEG_TO_RAD*vector.ones(2)
stance.dpLimitStance = vector.new{.04, .03, .03, .4, .4, .4}
stance.dqLegLimit = vector.new{10,10,45,90,45,10}*DEG_TO_RAD

stance.sitHeight = 0.75
stance.dHeight = 0.01 --4cm per sec


------------------------------------
-- ZMP preview stepping values
------------------------------------
local zmpstep = {}

--SJ: now we use walk parmas to generate these
zmpstep.param_r_q = 10^-6
zmpstep.preview_tStep = 0.010 --10ms
zmpstep.preview_interval = 3.0 --3s needed for slow step (with tStep ~3s)

zmpstep.params = true;

if IS_WEBOTS then

  --Webots uses different tZMP

print("HEREHERE")

  zmpstep.param_k1_px={-449.159605,-373.126940,-79.851979}
  zmpstep.param_a={
    {1.000000,0.010000,0.000050},
    {0.000000,1.000000,0.010000},
    {0.000000,0.000000,1.000000},
  }
  zmpstep.param_b={0.000000,0.000050,0.010000,0.010000}
  zmpstep.param_k1={
      352.062033,64.137229,-1.977011,-16.841151,-19.871597,
      -20.177262,-19.862977,-19.414928,-18.945240,-18.479594,
      -18.023703,-17.578669,-17.144534,-16.721101,-16.308122,
      -15.905342,-15.512511,-15.129382,-14.755717,-14.391281,
      -14.035847,-13.689192,-13.351100,-13.021358,-12.699761,
      -12.386107,-12.080200,-11.781849,-11.490868,-11.207074,
      -10.930289,-10.660341,-10.397060,-10.140282,-9.889847,
      -9.645597,-9.407380,-9.175047,-8.948453,-8.727455,
      -8.511916,-8.301701,-8.096678,-7.896718,-7.701698,
      -7.511495,-7.325989,-7.145065,-6.968611,-6.796514,
      -6.628668,-6.464968,-6.305311,-6.149598,-5.997730,
      -5.849614,-5.705156,-5.564266,-5.426856,-5.292840,
      -5.162134,-5.034656,-4.910327,-4.789069,-4.670806,
      -4.555464,-4.442971,-4.333256,-4.226251,-4.121889,
      -4.020105,-3.920835,-3.824017,-3.729590,-3.637496,
      -3.547676,-3.460075,-3.374638,-3.291311,-3.210042,
      -3.130780,-3.053476,-2.978082,-2.904549,-2.832833,
      -2.762889,-2.694672,-2.628140,-2.563252,-2.499966,
      -2.438243,-2.378045,-2.319334,-2.262073,-2.206227,
      -2.151760,-2.098638,-2.046829,-1.996299,-1.947017,
      -1.898953,-1.852076,-1.806357,-1.761767,-1.718279,
      -1.675865,-1.634498,-1.594154,-1.554805,-1.516429,
      -1.479001,-1.442498,-1.406896,-1.372174,-1.338309,
      -1.305281,-1.273068,-1.241652,-1.211011,-1.181128,
      -1.151982,-1.123557,-1.095833,-1.068795,-1.042424,
      -1.016705,-0.991621,-0.967157,-0.943297,-0.920026,
      -0.897330,-0.875195,-0.853607,-0.832551,-0.812016,
      -0.791988,-0.772454,-0.753403,-0.734823,-0.716701,
      -0.699027,-0.681789,-0.664977,-0.648581,-0.632588,
      -0.616991,-0.601779,-0.586942,-0.572472,-0.558359,
      -0.544594,-0.531169,-0.518075,-0.505304,-0.492848,
      -0.480700,-0.468851,-0.457294,-0.446022,-0.435029,
      -0.424306,-0.413847,-0.403646,-0.393697,-0.383992,
      -0.374526,-0.365294,-0.356288,-0.347504,-0.338936,
      -0.330579,-0.322427,-0.314475,-0.306719,-0.299152,
      -0.291772,-0.284572,-0.277549,-0.270697,-0.264014,
      -0.257493,-0.251132,-0.244926,-0.238872,-0.232965,
      -0.227201,-0.221578,-0.216092,-0.210738,-0.205514,
      -0.200417,-0.195442,-0.190588,-0.185850,-0.181226,
      -0.176713,-0.172309,-0.168009,-0.163812,-0.159714,
      -0.155714,-0.151808,-0.147994,-0.144270,-0.140632,
      -0.137080,-0.133610,-0.130221,-0.126909,-0.123674,
      -0.120512,-0.117422,-0.114402,-0.111449,-0.108562,
      -0.105739,-0.102979,-0.100278,-0.097636,-0.095050,
      -0.092519,-0.090042,-0.087616,-0.085239,-0.082912,
      -0.080631,-0.078395,-0.076202,-0.074052,-0.071943,
      -0.069872,-0.067840,-0.065844,-0.063882,-0.061954,
      -0.060059,-0.058194,-0.056359,-0.054551,-0.052771,
      -0.051016,-0.049286,-0.047578,-0.045892,-0.044227,
      -0.042581,-0.040953,-0.039341,-0.037745,-0.036164,
      -0.034595,-0.033038,-0.031492,-0.029955,-0.028427,
      -0.026905,-0.025389,-0.023878,-0.022370,-0.020864,
      -0.019358,-0.017853,-0.016345,-0.014834,-0.013320,
      -0.011799,-0.010272,-0.008736,-0.007191,-0.005636,
      -0.004068,-0.002486,-0.000889,0.000724,0.002355,
      0.004005,0.005676,0.007370,0.009087,0.010829,
      0.012599,0.014397,0.016226,0.018086,0.019980,
      0.021910,0.023876,0.025882,0.027928,0.030017,
      0.032149,0.034319,0.036504,0.038590,0.040082,
      0.038831,0.025526,-0.040123,-0.332466,-1.605949,
      }
else
  zmpstep.param_k1_px={-576.304158,-389.290169,-68.684425}
  zmpstep.param_a={
    {1.000000,0.010000,0.000050},
    {0.000000,1.000000,0.010000},
    {0.000000,0.000000,1.000000},
  }
  zmpstep.param_b={0.000000,0.000050,0.010000,0.010000}
  zmpstep.param_k1={
      362.063442,105.967958,16.143995,-14.954972,-25.325109,
      -28.390091,-28.892019,-28.505769,-27.822565,-27.050784,
      -26.263560,-25.486256,-24.727376,-23.989477,-23.273029,
      -22.577780,-21.903233,-21.248818,-20.613950,-19.998050,
      -19.400555,-18.820915,-18.258596,-17.713080,-17.183867,
      -16.670467,-16.172409,-15.689235,-15.220498,-14.765769,
      -14.324628,-13.896668,-13.481497,-13.078731,-12.688001,
      -12.308946,-11.941218,-11.584477,-11.238396,-10.902656,
      -10.576948,-10.260972,-9.954438,-9.657062,-9.368572,
      -9.088702,-8.817195,-8.553799,-8.298273,-8.050383,
      -7.809898,-7.576600,-7.350271,-7.130705,-6.917699,
      -6.711057,-6.510589,-6.316110,-6.127442,-5.944411,
      -5.766848,-5.594590,-5.427479,-5.265360,-5.108085,
      -4.955508,-4.807490,-4.663894,-4.524588,-4.389444,
      -4.258337,-4.131147,-4.007757,-3.888053,-3.771925,
      -3.659267,-3.549974,-3.443946,-3.341085,-3.241298,
      -3.144491,-3.050577,-2.959468,-2.871080,-2.785333,
      -2.702148,-2.621447,-2.543158,-2.467207,-2.393524,
      -2.322043,-2.252697,-2.185423,-2.120158,-2.056843,
      -1.995419,-1.935830,-1.878021,-1.821939,-1.767532,
      -1.714751,-1.663545,-1.613870,-1.565678,-1.518926,
      -1.473570,-1.429569,-1.386883,-1.345471,-1.305297,
      -1.266322,-1.228512,-1.191831,-1.156246,-1.121723,
      -1.088232,-1.055741,-1.024221,-0.993642,-0.963977,
      -0.935197,-0.907277,-0.880192,-0.853915,-0.828423,
      -0.803692,-0.779701,-0.756425,-0.733845,-0.711940,
      -0.690689,-0.670072,-0.650071,-0.630668,-0.611844,
      -0.593583,-0.575867,-0.558680,-0.542007,-0.525831,
      -0.510139,-0.494915,-0.480146,-0.465818,-0.451919,
      -0.438434,-0.425352,-0.412661,-0.400349,-0.388404,
      -0.376817,-0.365575,-0.354670,-0.344090,-0.333826,
      -0.323868,-0.314208,-0.304837,-0.295745,-0.286925,
      -0.278368,-0.270067,-0.262014,-0.254201,-0.246622,
      -0.239269,-0.232135,-0.225214,-0.218500,-0.211987,
      -0.205668,-0.199538,-0.193590,-0.187820,-0.182223,
      -0.176792,-0.171523,-0.166412,-0.161453,-0.156642,
      -0.151975,-0.147446,-0.143053,-0.138791,-0.134655,
      -0.130643,-0.126750,-0.122974,-0.119309,-0.115754,
      -0.112305,-0.108958,-0.105710,-0.102559,-0.099502,
      -0.096535,-0.093657,-0.090863,-0.088153,-0.085523,
      -0.082970,-0.080493,-0.078089,-0.075756,-0.073491,
      -0.071293,-0.069160,-0.067089,-0.065079,-0.063128,
      -0.061234,-0.059394,-0.057609,-0.055875,-0.054191,
      -0.052556,-0.050968,-0.049425,-0.047926,-0.046470,
      -0.045056,-0.043681,-0.042345,-0.041046,-0.039783,
      -0.038556,-0.037362,-0.036200,-0.035070,-0.033971,
      -0.032900,-0.031858,-0.030843,-0.029855,-0.028892,
      -0.027953,-0.027037,-0.026144,-0.025273,-0.024422,
      -0.023591,-0.022779,-0.021986,-0.021209,-0.020450,
      -0.019706,-0.018977,-0.018262,-0.017561,-0.016873,
      -0.016197,-0.015532,-0.014877,-0.014233,-0.013597,
      -0.012970,-0.012351,-0.011739,-0.011133,-0.010533,
      -0.009938,-0.009347,-0.008760,-0.008176,-0.007594,
      -0.007013,-0.006433,-0.005854,-0.005274,-0.004692,
      -0.004108,-0.003522,-0.002932,-0.002338,-0.001739,
      -0.001134,-0.000522,0.000097,0.000724,0.001360,
      0.002006,0.002663,0.003331,0.004012,0.004706,
      0.005414,0.006138,0.006877,0.007632,0.008400,
      0.009175,0.009932,0.010604,0.010998,0.010561,
      0.007734,-0.001906,-0.030876,-0.114606,-0.353382,
      }
end

------------------------------------
-- Associate with the table
Config.walk    = walk
Config.stance  = stance
Config.zmpstep = zmpstep

return Config
