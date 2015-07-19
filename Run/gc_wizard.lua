#!/usr/bin/env luajit
---------------------------
-- Game State Manager
-- (c) 2014 Stephen McGill
---------------------------
dofile'../fiddle.lua'
local libGC = require'GameControlReceiver.ffi'
require'gcm'
local Body = require('Body')
-- Cache some functions
local get_time = Body.get_time
local util = require'util'
local color = util.color
-- Cleanly exit on Ctrl-C
local running = true
local function shutdown () running = false end
local signal
if not IS_WEBOTS then
  signal = require'signal'
  signal.signal("SIGINT", shutdown)
  signal.signal("SIGTERM", shutdown)
end

local ENABLE_COACH = false
local teamId = 44  --36
local gc = libGC.init(teamId, 1, '192.168.44.1')

local OUR_GAME
local ret, msg
local send_count, recv_count = 0, 0
local t, t_send, t_pkt, t_switch = 0, 0, 0, 0
local last_pkt, cur_pkt, pkt = -1, -1
local led_count, last_position = 0
local rgb = {0, 0, 0}
gcm.set_game_role(Config.default_role or 2) --Testing
gcm.set_game_state(Config.default_state or 5) --Pre-init

--To stop the head movement for tester role
local head_ch = require'simple_ipc'.new_publisher('HeadFSM!')
local function process_switch(t)
	if t-t_switch < 1 then return end
	t_switch = t
	led_count = led_count +1
--	local current_lidar_deg = Body.get_lidar_position()[1] * RAD_TO_DEG
	local current_lidar_deg = 90
	local cur_position
	if current_lidar_deg>45 then
		cur_position = 1
	elseif current_lidar_deg<-45 then
		cur_position = -1
	else
		cur_position = 0
	end
	-- Check the last position
	if cur_position~=last_position then
		last_position = cur_position
		local role, state
		if cur_position == 1 then
			role = 1 -- One: Attacker
			state = 0
		elseif cur_position == -1 then
			role = 0 --Zero: goalie
			state = 0
		else
			-- Testing role/stae
			role = 2
			state = 6
			head_ch:send'teleop'
			gcm.set_game_autoadvance(0)
		end
		-- Set in shared memory
		gcm.set_game_role(role)
		gcm.set_game_state(state)
		-- Set the LEDs
		if role==0 then
			rgb = {0,0,255}
		elseif role==1 then
			rgb = {255,0,0}
		else
			rgb = {255,0,255}
		end
	local intensity = 1.0
		Body.set_head_led_red(rgb[1]*intensity)
    Body.set_head_led_blue(rgb[3]*intensity)
    Body.set_head_led_green(rgb[3]*intensity)
	end
	-- Change the intensity if GC packets received
	local intensity = 1.0
	local gamecontroller_timeout = Config.gamecontroller_timeout or 5.0
	if get_time() - gcm.get_game_gctime() > gamecontroller_timeout then
		intensity = led_count % 2
	end
end

local function process_packet(pkt, t)
	if not pkt then return end
	local teams = pkt.teams
	OUR_GAME = teams[0].teamNumber==teamId or teams[1].teamNumber==teamId
	--[[
	print("temaId:"..teamId)
	print("teams[0]:"..teams[0].teamNumber)
	print("teams[1]:"..teams[1].teamNumber)
	if OUR_GAME == true then
		print("OUR_GAME")
	end
	if OUR_GAME == false then
		print("Not OUR_GAME")
	end
	--]]

	--print("temaNumber:"..teamNumber)

	-- If not our game, then return
	if not OUR_GAME then return end
	-- Set things

	local Thorid
  local opposite
	if teams[0].teamNumber==teamId then
		Thorid = 0
		opposite = 1
	else
		Thorid = 1
		opposite = 0
	end
	gcm.set_game_gctime(t) -- GC time of received packet
	gcm.set_game_state(pkt.state)
	game_ch:send(libGC.state_to_name[pkt.state]:lower())
--	gcm.set_game_secsremaining(pkt.secsRemaining)
	gcm.set_game_timeleft(pkt.secsRemaining)

	t_timeupdate = t
	-- Save the packet number
	last_pkt = cur_pkt
	cur_pkt = pkt.packetNumber

	-- Send a return to the game controller
	ret, msg = gc:send_return()
	if msg then print("GC | Return error", msg) end
	-- Increment the number of packets we have received
	recv_count = recv_count + 1
	--
	if cur_pkt~=last_pkt then t_pkt = t end
	-- Print debug
	local state_name = libGC.state_to_name[pkt.state] or "UNKNOWN"
	local debug_str = table.concat({
		color("State: "..state_name, 'yellow'),
		color(pkt.secsRemaining..' seconds left', 'red'),
		--color("(ThorWin)" .. pkt.teams[Thorid].score .. " : " .. pkt.teams[opposite].score .. "(Team A)",'blue'),
    color(
      string.format("THORwIn [%d] | (Team A) [%d]", tonumber(pkt.teams[Thorid].score) or -1, tonumber(pkt.teams[opposite].score) or -1),
      'blue'),
		color('Packet '..cur_pkt, 'green'),
		''
	}, '\n')
	print(debug_str)
	--print("version:"..pkt.version)
	--print("playersPerTeam:"..pkt.playersPerTeam)
	--print("score:"..pkt.score)
	--print(pkt.teams[0].score .. " : " .. pkt.teams[1].score)

--		color(pkt.teams[0].score .. " : " .. pkt.teams[1].score,'blue'),


end

while running do
  collectgarbage('step')
	pkt = gc:wait_for_gc()
  t = get_time()
	if pkt then
		process_packet(pkt, t)
	end
	--print(pkt)
--	if pkt then
--		print("secsRemaing:"..pkt.secsRemaining)
--		if (pkt.state == 2) then
--		print("state:".."set")
--		end
--		if (pkt.state == 3) then
--		print("state:".."play")
--		end
--		if (pkt.state == 4) then
--		print("state:".."finish")
--	 	end

--	end
	--process_switch(t)
  if ENABLE_COACH and t - t_send > SEND_RATE then
    t_send = t
		ret, msg = gc:send_coach("go team!")
    if msg then print("GC | Coach error", msg) end
    send_count = send_count + 1
  end
	if t - t_pkt > 2 then
		--print("GC | TIMEOUT")
	end
end
