module(..., package.seeall);
local util = require('util')
local parse_hostname = require('parse_hostname')
local vector = require('vector')
local os = require('os')

platform = {};
platform.name = 'WebotsTHOROP'

-- Parameters Files
params = {}
params.name = {"Walk", "World", "Kick", "Vision", "FSM", "Camera"};
params.World_Platform = "THOROP"
util.LoadConfig(params, platform)

-- Device Interface Libraries
dev = {};
dev.body = 'WebotsTHOROPBody'; 
dev.camera = 'WebotsOPCam';
dev.kinematics = 'THOROPKinematics';
dev.game_control='WebotsGameControl';
dev.team='TeamNull';

dev.walk = 'HumbleWalk';
dev.crawl = 'ScrambleCrawl';
--dev.largestep = 'ZMPStep';
dev.largestep = 'ZMPStepStair';

--dev.walk = 'ZMPPreviewWalk';
--dev.walk = 'zmpstep';

--Jumble*** are for uneven grounds 
--dev.walk = 'JumbleWalk';
--dev.crawl = 'JumbleCrawl';

dev.kick = 'NewKick';





dev.ip_wired = '192.168.123.255'; 
dev.ip_wired_port = 111111;
dev.ip_wireless = '192.168.1.255'; --Our Router
dev.ip_wireless_port = 54321;

-- Game Parameters
game = {};
game.teamNumber = (os.getenv('TEAM_ID') or 22) + 0;
-- webots player ids begin at 0 but we use 1 as the first id
game.playerID = (os.getenv('PLAYER_ID') or 0) + 1;
game.robotID = game.playerID;
game.teamColor = 1;
game.nPlayers = 2;--for teensize: 2 players
game.role = game.playerID-1; -- 0 for goalie


-- FSM Parameters
fsm.game = 'RoboCup';
fsm.body = {'CharliPlayer'};
fsm.head = {'GeneralPlayer'}; 

fsm.enable_obstacle_detection = 1;
fsm.playMode = 3; --1 for demo, 2 for orbit, 3 for direct approach
fsm.enable_walkkick = 1;
fsm.enable_sidekick = 1;

-- Team Parameters

team = {};
team.msgTimeout = 5.0;
team.nonAttackerPenalty = 6.0; -- eta sec
team.nonDefenderPenalty = 0.5; -- dist from goal

--Head Parameters
head = {};
head.camOffsetZ = 0.41;
head.pitchMin = -35*math.pi/180;
head.pitchMax = 68*math.pi/180;
head.yawMin = -120*math.pi/180;
head.yawMax = 120*math.pi/180;
head.cameraPos = {{0.05, 0.0, 0.05}} --OP, spec value, may need to be recalibrated
head.cameraAngle = {{0.0, 0.0, 0.0}}; --Default value for production OP
head.neckZ=0.42; --From CoM to neck joint , CHARLI
head.neckX=0.0; --From CoM to neck joint , CHARLI

-- keyframe files
km = {};
km.standup_front = 'km_Charli_StandupFromFront.lua';
km.standup_back = 'km_Charli_StandupFromBack.lua';

--Sit/stand stance parameters
--Charli never sits down or relax

sit_disable = 1;

stance={};
stance.hardnessLeg = 1;

stance.bodyHeightSit = 0.75;
stance.supportXSit = -0.00;
stance.bodyHeightDive= 0.65;

stance.bodyTiltStance=0*math.pi/180; --bodyInitial bodyTilt, 0 for webots
stance.dpLimitStance = vector.new({.4, .3, .4, .05, .4, .1})*0.6;
stance.dpLimitStance=vector.new({.04, .03, .07, .4, .4, .4});
stance.dpLimitSit=vector.new({.1,.01,.06,.1,.3,.1})*2;
stance.delay = 80; 


walk.use_alternative_trajectory = 1;
