module(..., package.seeall);
require('Body')
require('fsm')
require('gcm')

require('headIdle')
require('headStart')
require('headReady')
require('headReadyLookGoal')
require('headScan')
require('headTrack')
require('headLookGoal')
require('headSweep')
require('headKickFollow')

sm = fsm.new(headIdle);
sm:add_state(headStart);
sm:add_state(headReady);
sm:add_state(headReadyLookGoal);
sm:add_state(headScan);
sm:add_state(headTrack);
sm:add_state(headLookGoal);
sm:add_state(headSweep);
sm:add_state(headKickFollow);

sm:set_transition(headStart, 'done', headTrack);

sm:set_transition(headReady, 'done', headReadyLookGoal);

sm:set_transition(headReadyLookGoal, 'timeout', headReady);
sm:set_transition(headReadyLookGoal, 'lost', headReady);

sm:set_transition(headTrack, 'lost', headScan);
sm:set_transition(headTrack, 'timeout', headLookGoal);

sm:set_transition(headLookGoal, 'timeout', headTrack);
sm:set_transition(headLookGoal, 'lost', headSweep);

sm:set_transition(headSweep, 'done', headTrack);

sm:set_transition(headScan, 'ball', headTrack);
sm:set_transition(headScan, 'timeout', headScan);

--Added for GeneralPlayer Body FSM
sm:set_transition(headKickFollow, 'lost', headScan);
sm:set_transition(headKickFollow, 'ball', headTrack);

-- set state debug handle to shared memory settor
sm:set_state_debug_handle(gcm.set_fsm_head_state);

function entry()
  sm:entry()
end

function update()
  sm:update();
end

function exit()
  sm:exit();
end
