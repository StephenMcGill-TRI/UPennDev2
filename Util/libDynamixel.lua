-- Dynamixel Library
-- (c) 2013 Stephen McGill
-- (c) 2013 Daniel D. Lee
-- Support: http://support.robotis.com/en/product/dynamixel_pro/communication/instruction_status_packet.htm

local libDynamixel = {}
local DP1 = require'DynamixelPacket1' -- 1.0 protocol
local DP2 = require'DynamixelPacket2' -- 2.0 protocol
libDynamixel.DP2 = DP2
local unix = require'unix'
local stty = require'stty'
local using_status_return = true
-- 120Hz default timeout
local READ_TIMEOUT = 1 / 120

--------------------
-- Convienence functions for reading dynamixel packets
DP1.parse_status_packet = function(pkt) -- 1.0 protocol
   local t = {}
   t.id = pkt:byte(3)
   t.length = pkt:byte(4)
   t.error = pkt:byte(5)
   t.parameter = {pkt:byte(6,t.length+3)}
   t.checksum = pkt:byte(t.length+4)
   return t
end

DP2.parse_status_packet = function(pkt) -- 2.0 protocol
  --print('status pkt',pkt:byte(1,#pkt) )
  local err, len = pkt:byte(9), pkt:byte(6) + 256 * pkt:byte(7)
  if err>0 then
    return {
      id = pkt:byte(5),
      length = len,
      instruction = pkt:byte(8),
      error = err,
      checksum = string.char(pkt:byte(10), pkt:byte(11))
    }
  else
    return {
      id = pkt:byte(5),
      length = len,
      instruction = pkt:byte(8),
      error = err,
      parameter = {pkt:byte(10, len+5)},
      raw_parameter = pkt:sub(10, len+5),
      checksum = string.char(pkt:byte(len+6), pkt:byte(len+7))
    }
  end
end

-- RX (uses 1.0)
-- Format: { Register Address, Register Byte Size}
local rx_registers = {
  ['id'] = {3,1},
  ['baud'] = {4,1},
  ['delay'] = {5,1},
  ['torque_enable'] = {24,1},
  ['led'] = {25,1},
  ['command_position'] = {30,2},
  ['command'] = {30,2},
  ['position'] = {36,2},
  ['battery'] = {42,2},
  ['temperature'] = {43,1},
  torque_mode = {70,1},
  command_torque = {71,2},
  command_acceleration = {73,1},
  everything = {36,8},
}
libDynamixel.rx_registers = rx_registers

libDynamixel.model_number_lookup = {
  [-14336] = 'H42-20-S300-R',
  [1] = 'H54-100-S500-R',
  [1] = 'H54-200-S500-R',
  [1] = 'L54-60-S300-R',
  [29] = 'MX-28R'
}

-- MX
-- http://support.robotis.com/en/product/dynamixel/mx_series/mx-28.htm
-- Convention: {string.char( ADDR_LOW_BYTE, ADDR_HIGH_BYTE ), n_bytes_of_value}
local mx_registers = {
  ['model_number'] = {string.char(0,0),2},
  ['firmware'] = {string.char(2,0),1},
  ['id'] = {string.char(3,0),1},
  ['baud'] = {string.char(4,0),1},
  ['delay'] = {string.char(5,0),1},
  ['max_torque'] = {string.char(14,0),2},
  ['status_return_level'] = {string.char(16,0),1},
  ['torque_enable'] = {string.char(24,0),1},
  ['led'] = {string.char(25,0),1},

  -- Position PID Gains (position control mode)
  ['position_p'] = {string.char(28,0),1},
  ['position_i'] = {string.char(27,0),1},
  ['position_d'] = {string.char(26,0),1},

  ['command_position'] = {string.char(30,0),2},
-- Two for legacy support
  ['command'] = {string.char(30,0),2},
--
  ['velocity'] = {string.char(32,0),2},
  ['position'] = {string.char(36,0),2},
  ['speed'] = {string.char(38,0),2},
  ['load'] = {string.char(40,0),2},

  ['battery'] = {string.char(42,0),2},
  ['temperature'] = {string.char(43,0),1},

  -- For the MX-106
  torque_mode = {string.char(70,0),1},
  command_torque = {string.char(71,0),2},
  command_acceleration = {string.char(73,0),1},

  -- all dat!
  everything = {string.char(36,0),8},
}
libDynamixel.mx_registers = mx_registers

-- Dynamixel PRO
-- English to Hex Addresses of various commands/information
-- Convention: string.char( LOW_BYTE, HIGH_BYTE )
-- http://support.robotis.com/en/product/dynamixel_pro/control_table.htm
local nx_registers = {

  -- New API --
  -- ENTER EEPROM AREA

  -- General Operation information
  ['model_number']  = {string.char(0x00,0x00),2},
  ['model_information'] = {string.char(0x02,0x00),4},
  ['firmware'] =   {string.char(0x06,0x00),1},
  ['id'] =   {string.char(0x07,0x00),1},
  -- Baud
  --[[
  0: 2400 ,1: 57600, 2: 115200, 3: 1Mbps, 4: 2Mbps
  5: 3Mbps, 6: 4Mbps, 7: 4.5Mbps, 8: 10.5Mbps
  --]]
  ['baud_rate'] = {string.char(0x08,0x00),1},
  -- Delay in us: wish to have zero
  ['return_delay_time'] = {string.char(9,0),1},

  -- Operation Mode
  -- Mode 0: Torque Control
  -- Mode 1: Velocity Control
  -- Mode 2: Position Control
  -- Mode 3: position-Velocity Control
  ['mode'] = {string.char(0x0B,0x00),1},
  ['homing_offset'] = {string.char(13,0x00),4},

  -- Limits
  ['max_temperature'] = {string.char(0x15,0x00,1)},
  ['max_voltage'] = {string.char(0x16,0x00),2},
  ['min_voltage'] = {string.char(0x18,0x00),2},
  ['max_acceleration'] = {string.char(0x1A,0x00),4},
  ['max_torque'] = {string.char(0x1E,0x00),2},
  ['max_velocity'] = {string.char(0x20,0x00),4},
  ['max_position'] = {string.char(0x24,0x00),4},
  ['min_position'] = {string.char(0x28,0x00),4},
  --
  ['data1_mode'] = {string.char(44,0x00),1},
  ['data2_mode'] = {string.char(45,0x00),1},
  ['data3_mode'] = {string.char(46,0x00),1},
  ['data4_mode'] = {string.char(47,0x00),1},
  --
  ['shutdown'] = {string.char(0x30,0x00),1},

  -- ENTER RAM AREA
  ['torque_enable'] = {string.char(0x32,0x02),1},
  -- Position Options --
  -- Position Commands (position control mode)
  ['command_position'] = {string.char(0x54,0x02),4},
  ['command_velocity'] = {string.char(0x58,0x02),4},
  ['command_acceleration'] = {string.char(0x5E,0x02),4},
  -- Position PID Gains (position control mode)
  ['position_p'] = {string.char(0x52,0x02),2},
  ['position_i'] = {string.char(0x50,0x02),2},
  ['position_d'] = {string.char(0x4E,0x02),2},
  -- Velocity PID Gains (position control mode)
  ['velocity_p'] = {string.char(0x46,0x02),2},
  ['velocity_i'] = {string.char(0x4A,0x02),2},
  ['velocity_d'] = {string.char(0x4C,0x02),2},

  -- Low Pass Fitler settings
  ['position_lpf'] = {string.char(0x42,0x02),4},
  ['velocity_lpf'] = {string.char(0x46,0x02),4},
  -- Feed Forward mechanism
  ['acceleration_ff'] = {string.char(0x3A,0x02),4},
  ['velocity_ff'] = {string.char(0x3E,0x02),4},

  -- Torque options --
  -- Commanded Torque (torque control mode)
  ['command_torque'] = {string.char(0x5C,0x02),4},
  -- Current (V=iR) PI Gains (torque control mode)
  ['current_p'] = {string.char(0x38,0x02),2},
  ['current_i'] = {string.char(0x36,0x02),2},

  -- LED lighting
  ['led'] = {string.char(0x33,0x02),1}, -- legacy support (red)
  ['led_red'] = {string.char(0x33,0x02),1},
  ['led_green'] = {string.char(0x34,0x02),1},
  ['led_blue'] = {string.char(0x35,0x02),1},

  -- Present information
  ['position'] = {string.char(0x63,0x02),4},
  ['velocity'] = {string.char(0x67,0x02),4},
  ['current'] = {string.char(0x6D,0x02),2},
  ['load'] = {string.char(0x6B,0x02),2},
  ['voltage'] = {string.char(0x6F,0x02),2},
  ['temperature'] = {string.char(0x71,0x02),1},

  -- External Data
  ['data1'] = {string.char(0x72,0x02),2},
  ['data2'] = {string.char(0x74,0x02),2},
  ['data3'] = {string.char(0x76,0x02),2},
  ['data4'] = {string.char(0x78,0x02),2},
  --
  ['data']  = {string.char(0x72,0x02),8},

  -- Status return
  ['status_return_level'] = {string.char(0x7B,0x03),1},
}
libDynamixel.nx_registers = nx_registers

-- Assume MX and NX are at least similar here
libDynamixel.registers_sensor = {
  'position', 'velocity', 'current', 'load', 'voltage', 'temperature',
}

--------------------
-- Convienence functions for constructing Sync Write instructions
local function sync_write_byte (ids, addr, data)
  local all_data = nil
  local nid = #ids
  -- All get the same value
  if type(data)=='number' then
    all_data = data
  else
    assert(nid==#data,'Incongruent ids and data')
  end

  local t = {}
  local n = 1
  local len = 1 -- byte
  for i = 1,nid do
    t[n] = ids[i]
    t[n+1] = all_data or data[i]
    n = n + len + 1
  end

  return t
end

local function sync_write_word (ids, addr, data)
  local all_data = nil
  local nid = #ids
  if type(data)=='number' then
    -- All get the same value
    all_data = data
  else
    assert(nid==#data,'Incongruent ids and data')
  end

  local t = {}
  local n = 1
  local len = 2 -- word
  for i = 1,nid do
    t[n] = ids[i];
    local val = all_data or data[i]
    -- Word to byte is the same for both packet types...
    t[n+1],t[n+2] = DP2.word_to_byte(val)
    n = n + len + 1;
  end
  return t
end

local function sync_write_dword (ids, addr, data)
  local all_data = nil
  local nid = #ids
  local len = 4
  if type(data)=='number' then
    -- All get the same value
		all_data = data
	else
		assert(nid==#data,'Incongruent ids and data. nids:'..nid..' #:'..#data)
	end
  local t = {};
  local n = 1;
  for i = 1,nid do
    t[n] = ids[i];
    local val = all_data or data[i]
    t[n+1],t[n+2],t[n+3],t[n+4] = DP2.dword_to_byte(val)
    n = n + len + 1;
  end
  return t
end

--------------------
-- Initialize functions for reading/writing to NX motors
local nx_single_write = {}
nx_single_write[1] = DP2.write_byte
nx_single_write[2] = DP2.write_word
nx_single_write[4] = DP2.write_dword

local mx_single_write = {}
mx_single_write[1] = DP2.write_byte
mx_single_write[2] = DP2.write_word
mx_single_write[4] = DP2.write_dword

local rx_single_write = {}
rx_single_write[1] = DP1.write_byte
rx_single_write[2] = DP1.write_word
rx_single_write[4] = DP1.write_dword

local sync_write = {}
sync_write[1] = sync_write_byte
sync_write[2] = sync_write_word
sync_write[4] = sync_write_dword

local byte_to_number = {}
byte_to_number[1] = function(byte) return byte end
byte_to_number[2] = DP2.byte_to_word
byte_to_number[4] = DP2.byte_to_dword
libDynamixel.byte_to_number = byte_to_number

-- Old get status method
local function get_status (fd, npkt, protocol, timeout)
  -- TODO: Is this the best default timeout for the new PRO series?
  timeout = timeout or READ_TIMEOUT
	npkt = npkt or 1
	local DP = protocol==1 and DP1 or DP2
	-- Form the temporary variables
  local status_str = ''
	local full_status_str = ''
  local statuses = {}
	local in_timeout = true
	local t0 = unix.time()
	local s, pkts
  while in_timeout or s do
		-- Wait for any packets
		--local status, ready = unix.select({fd},timeout)
		unix.select({fd},timeout)
    --local tf = unix.time()
    --print("t_diff",tf-t0,1/(tf-t0))
    s = unix.read(fd)
    if s then
			full_status_str = full_status_str..s
      --print('Full Status str',#s,#full_status_str,pkts)
      pkts, status_str = DP.input(status_str..s)
      --print(pkts,'packets',#pkts,'of',npkt)
      --print('PACKET', s:byte(1,-1))
      --print(#status_str, 'LEFTOVER:', status_str:byte(1,-1))
			--util.ptable(pkts)
      if pkts then
        for p,pkt in ipairs(pkts) do
          table.insert(statuses, DP.parse_status_packet(pkt))
        end
        if #statuses>=npkt then return statuses end
      end -- if pkts
    end -- if s
		in_timeout = (unix.time()-t0)<timeout
  end
	--print('READ TIMEOUT',#statuses,'of',npkt,type(s),#status_str)
  return statuses, full_status_str
end

-- Set functions: returns the command to send on the chain
for k,v in pairs(nx_registers) do
  local addr, sz = unpack(v)
  local single_wr, sync_wr = nx_single_write[sz], sync_write[sz]
  libDynamixel['set_nx_'..k] = function(motor_ids, values, bus)
    -- Construct the instruction (single or sync)
    local single, instruction = type(motor_ids)=='number'
    if single then
      instruction = single_wr(motor_ids, addr, values)
    else
      local msg = sync_wr(motor_ids, addr, values)
      instruction = DP2.sync_write(addr, sz, string.char(unpack(msg)))
    end
		if not bus then return instruction end
		-- Clear the reading
		local clr = unix.read(bus.fd)
		-- Write the instruction to the bus
		stty.flush(bus.fd)
		local ret = unix.write(bus.fd, instruction)
		-- Grab any status returns
		if using_status_return and single then
			return get_status(bus.fd, 1)
		else
			return ret
		end
  end --function
end

-- Get NX functions
for k,v in pairs(nx_registers) do
  local addr, sz = unpack(v)
  libDynamixel['get_nx_'..k] = function( motor_ids, bus )
    -- Construct the instruction (single or sync)
    local instruction, nids
    if type(motor_ids)=='number' then
      -- Single motor
      instruction = DP2.read_data(motor_ids, addr, sz)
			nids = 1
    else
      instruction = DP2.sync_read(string.char(unpack(motor_ids)), addr, sz)
      nids = #motor_ids
    end
    -- If no pre-existing bus is specified, just return the instruction
    if not bus then return instruction end
    -- Clear old status packets
    local buf
    repeat buf = unix.read(bus.fd) until not buf
    -- Write the instruction to the bus
    stty.flush(bus.fd)
    local ret = unix.write(bus.fd, instruction)
    -- Grab the status of the register
    return get_status( bus.fd, nids )
  end --function
end

libDynamixel.mx_nx_bulk_write =
function( register, mx_ids, mx_vals, nx_ids, nx_vals, bus)
  -- Form the bulk packet
  local bulk_pkt = {}
  -- Add the MX motors
  local mx_reg  = libDynamixel.mx_registers[register]
  local mx_addr = mx_reg[1]
  local mx_sz   = mx_reg[2]
  print('mx_sz',mx_sz)
  for i,id in ipairs(mx_ids) do
    table.insert( bulk_pkt, {id,mx_addr,mx_sz,mx_vals[i]} )
  end
  -- Add the NX motors
  local nx_reg  = libDynamixel.nx_registers[register]
  local nx_addr = nx_reg[1]
  local nx_sz   = nx_reg[2]
  print('nx_sz',nx_sz)
  for i,id in ipairs(nx_ids) do
    table.insert(bulk_pkt, {id,nx_addr, nx_sz, nx_vals[i]})
  end
  -- Form and return the packet
  local instruction = DP2.bulk_write(bulk_pkt)

  if not bus then return instruction end

  -- Clear the reading
  local clr = unix.read(bus.fd)

  -- Write the instruction to the bus
  stty.flush(bus.fd)
  local ret = unix.write(bus.fd, instruction)

end

--------------------
-- Set MX functions
for k,v in pairs( mx_registers ) do
  local addr, sz = unpack(v)
  libDynamixel['set_mx_'..k] = function( motor_ids, values, bus )
    -- Construct the instruction (single or sync)
    local single = type(motor_ids)=='number'
    local instruction = nil
    if single then
      instruction = mx_single_write[sz](motor_ids, addr, values)
    else
      local msg = sync_write[sz](motor_ids, addr, values)
      instruction = DP2.sync_write(addr, sz, string.char(unpack(msg)))
    end

    if not bus then return instruction end

    -- Write the instruction to the bus
    stty.flush(bus.fd)
    local ret = unix.write(bus.fd, instruction)

    -- Grab any status returns
    if using_status_return and single then
      local status = get_status( bus.fd )
      if not status then return end
      local value = byte_to_number[sz]( unpack(status.parameter) )
      return status, value
    end

  end --function
end

--------------------
-- Get MX functions
for k,v in pairs( mx_registers ) do
  libDynamixel['get_mx_'..k] = function( motor_ids, bus )
    local addr = v[1]
    local sz = v[2]

    -- Construct the instruction (single or sync)
    local instruction
    local nids = 1
    if type(motor_ids)=='number' then
      -- Single motor
      instruction = DP2.read_data(motor_ids, addr, sz)
    else
      instruction = DP2.sync_read(string.char(unpack(motor_ids)), addr, sz)
      nids = #motor_ids
    end

    if not bus then return instruction end

    -- Clear old status packets
    local clear = unix.read( bus.fd )

    -- Write the instruction to the bus
    stty.flush(bus.fd)
    local ret = unix.write( bus.fd, instruction)

    -- Grab the status of the register
    return get_status( bus.fd, nids )

  end --function
end

--------------------
-- Set RX functions
for k,v in pairs(rx_registers) do
  libDynamixel['set_rx_'..k] = function( motor_ids, values, bus)
    local addr = v[1]
    local sz = v[2]

    -- Construct the instruction (single or sync)
    local single = type(motor_ids)=='number'
    local instruction = nil
    if single then
      instruction = rx_single_write[sz](motor_ids, addr, values)
    else
      local msg = sync_write[sz](motor_ids, addr, values)
      instruction = DP1.sync_write(addr, sz, string.char(unpack(msg)))
    end

    if not bus then return instruction end

    -- Write the instruction to the bus
    stty.flush(bus.fd)
    local ret = unix.write(bus.fd, instruction)

    -- Grab any status returns
    if using_status_return and single then
      local status = get_status( bus.fd, 1 )
      return status
    end

  end --function
end

--------------------
-- Get RX functions
for k,v in pairs(rx_registers) do
  libDynamixel['get_rx_'..k] = function( motor_id, bus )
    local addr = v[1]
    local sz = v[2]
    -- Single motor at a time for reading
    local instruction = DP1.read_data(motor_id, addr, sz)
    if not bus then return instruction end
    -- Clear old status packets
    local clear = unix.read(bus.fd)
    -- Write the instruction to the bus
    stty.flush(bus.fd)
    local ret = unix.write(bus.fd, instruction)
    -- Grab the status of the register
    local status = get_status( bus.fd, 1, 1 )
    -- If not data from the chain
    if not status then return end
    local value
    if sz==8 and #status.parameter==8 then
      -- Everything!
      value = {}
      -- In steps
      value.position = byte_to_number[2]( unpack(status.parameter,1,2) )
      local speed = byte_to_number[2]( unpack(status.parameter,3,4) )
      if speed>=1024 then speed = 1024-speed end
      -- To Radians per second
      value.speed = (speed * math.pi) / 270
      local load  = byte_to_number[2]( unpack(status.parameter,5,6) )
      if load>=1024 then load = 1024-load end
      -- To percent
      value.load = load / 10.24
      -- To Volts
      value.voltage = status.parameter[7] / 10
      -- Is Celsius already
      value.temperature = status.parameter[8]
    else
      local ff = byte_to_number[#status.parameter]
      if not ff then return end
      value = ff( unpack(status.parameter) )
    end
    return status, value
  end --function
end

--------------------
-- Ping functions
local function send_ping( bus, id, protocol, twait )
  protocol = protocol or 2
  local instruction = nil
  if protocol==1 then
    instruction = DP1.ping(id)
  else
    instruction = DP2.ping(id)
  end
  if not bus then return instruction end

  stty.flush(bus.fd)
  local ret    = unix.write(bus.fd, instruction)
  local status = get_status( bus.fd, 1, protocol, twait )
  if status then return status end
end

local function ping_probe(self, protocol, twait)
  local found_ids = {}
  protocol = protocol or 2
  twait = twait or READ_TIMEOUT
  local parse_model = lD.byte_to_number[lD.nx_registers.model_number[2]]
  local parse_firmware = lD.byte_to_number[lD.nx_registers.firmware[2]]
  local parse_delay = lD.byte_to_number[lD.nx_registers.return_delay_time[2]]
  for id=0, 253 do
    local status = send_ping( self, id, protocol, twait )
    if status and #status>0 then
			status = status[1]
      print( string.format('Found %d.0 Motor: %d\n',protocol, status.id) )
      table.insert( found_ids, status.id )
      -- Check the model number
      status = lD.get_nx_model_number(status.id, bus)
      status = status[1]
      local model = parse_model(unpack(status.parameter))
      print('\tModel: '..model)
      -- Check the firmware
      status = lD.get_nx_firmware(status.id, bus)
      status = status[1]
      local firmware = parse_firmware(unpack(status.parameter))
      print('\tFirmware: '..firmware)
      -- Check the status return level
      status = lD.get_nx_return_delay_time(m_id, bus)
      status = status[1]
      local delay = parse_delay(unpack(status.parameter))
      print('\tReturn Delay: '..delay)
    end
    -- Wait .1 ms
    unix.usleep(READ_TIMEOUT * 1e6)
  end
  return found_ids
end

local function close(self)
  return unix.close(self.fd)==0
end

local function reset(self)
  self:close()
  unix.usleep( 1e3 )
  self.fd = libDynamixel.open( self.ttyname )
end

--------------------
-- Generator of a new bus
function libDynamixel.new_bus(ttyname, ttybaud)
  -------------------------------
  -- Find the device
  local baud = ttybaud or 3000000;
  if not ttyname then
    local ttys = unix.readdir("/dev");
    for i=1,#ttys do
      if ttys[i]:find("tty.usb") or ttys[i]:find("ttyUSB") then
        ttyname = "/dev/"..ttys[i]
        -- TODO: Test if in use
        break
      end
    end
  end
  assert(ttyname, "Dynamixel tty not found");
  -------------------------------

  -------------------
  -- Setup serial port
  local fd = unix.open(ttyname, unix.O_RDWR+unix.O_NOCTTY+unix.O_NONBLOCK);
  assert(fd > 2, string.format("Could not open port %s, (%d)", ttyname, fd) );
  stty.raw(fd)
  stty.serial(fd)
  stty.speed(fd, baud)
  -------------------

  -------------------
  -- Object of the Dynamixel
  local obj = {
    fd = fd,
    ttyname = ttyname,
    baud = baud,
    close = close,
    reset = reset,
    ping_probe = ping_probe,
    ping = send_ping,
    nx_on_bus = nil, -- ids of nx
    mx_on_bus = nil, -- ids of mx
    ids_on_bus = nil, --all on the bus
    name = 'Default',
  }

  return obj
end

return libDynamixel
