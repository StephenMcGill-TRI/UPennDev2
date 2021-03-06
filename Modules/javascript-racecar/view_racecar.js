#!/usr/bin/env node

// Optional ZeroMQ
var zeromq;
try {
  zeromq = require('zeromq');
  // console.log("zeromq", e);
} catch (e) {
  zeromq = false;
}

// HTTP service
const finalhandler = require('finalhandler');
const http = require('http');
const serveStatic = require('serve-static');
const serve = serveStatic('public', {'index' : [ 'index.html', 'index.htm' ]});

// Multicast initialization
const dgram = require('dgram');
const MCL_PORT = 6556;
const MCL_ADDRESS = "239.255.65.56";
// const MCL_PORT = 7667;
// const MCL_ADDRESS = "239.255.76.67";
const mcl_transport = dgram.createSocket({type : 'udp4', reuseAddr : true});

// WebSockets initialization
const WebSocket = require('ws');
const wss = new WebSocket.Server({port : 9001});

// Store the fragments of received messages
const getn = (arr) => arr.reduce((n, v) => n + (Buffer.isBuffer(v) ? 1 : 0), 0);
const fragments = new Map();

// Store the latest fully formed messages.
const latest = new Map();
// Broadcast at a consistent rate. (10Hz is 100ms)
const CONSISTENT_RATE_MS = 100;
// Should we send consistently or immediately?
const SEND_CONSISTENTLY = false;

// Multicast logic
mcl_transport.bind(MCL_PORT, MCL_ADDRESS, () => {
  console.log("Buffer", mcl_transport.getRecvBufferSize());
  mcl_transport.setRecvBufferSize(Math.pow(2, 21));
  console.log("Buffer", mcl_transport.getRecvBufferSize());
  const address = mcl_transport.address();
  console.log(`server listening ${address.address}:${address.port}`);
  mcl_transport.setBroadcast(true);
  mcl_transport.setMulticastTTL(0);
  mcl_transport.addMembership(MCL_ADDRESS);
});

mcl_transport.on('error', (err) => {
  console.log(`mtransport error:\n${err.stack}`);
  mcl_transport.close();
});

mcl_transport.on('message', (msg, rinfo) => {
  const t = Date.now();
  // console.log(`server got message from ${rinfo.address}:${rinfo.port}`,
  // msg.length);
  let ch = false;
  switch (msg.readUInt16BE(0)) {
  case 0x81d9: // msgpack header
    wss.broadcast(msg);
    return;
  case 0x4c43: // LCM message type
    break;
  }
  switch (msg.readUInt16BE(2)) {
  case 0x3032: // Decode LCM single: 0x4c43 3032
    const seq_id0 = msg.readUInt32BE(4);
    const ch_off0 = msg.indexOf(0, 8);
    ch = msg.slice(8, ch_off0);
    const payload = msg.slice(ch_off0 + 1);
    const msg_mp =
        Buffer.concat([ Buffer.from([ 0x81, 0xd9, ch.length ]), ch, payload ]);
    // console.log(`LCM0 [${seq_id0}]`, ch.toString('utf8'), msg_mp.length);
    if (SEND_CONSISTENTLY) {
      // Wait for the interval
      latest.set(ch, msg_mp);
    } else {
      // Send now
      wss.broadcast(msg_mp);
    }
    return;
  case 0x3033: // Decode LCM multiple: 0x4c43 3033
    const seq_id = msg.readUInt32BE(4);
    const seq_len = msg.readUInt32BE(8);
    const frag_off = msg.readUInt32BE(12);
    const frag_id = msg.readUInt16BE(16);
    const nfrag = msg.readUInt16BE(18);
    // Process the fragment sent to us
    var frag;
    const offset = 20;
    if (frag_id === 0) {
      const ch_off = msg.indexOf(0, offset);
      ch = msg.slice(offset, ch_off);
      if (ch.length > 255) {
        ch = ch.slice(0, 255);
      }
      frag = Buffer.concat(
          [ Buffer.from([ 0xd9, ch.length ]), ch, msg.slice(ch_off + 1) ]);
    } else {
      frag = msg.slice(offset);
    }
    // Manage the unordered fragments
    var frag_list;
    const uuid = `${seq_id}-${nfrag}`;
    if (fragments.has(uuid)) {
      const fragment = fragments.get(uuid);
      // Update the time of the latest packet
      fragment[0] = t;
      // Grab the list of fragments
      frag_list = fragment[1];
      // Grab the channel
      ch = fragment[2];
    } else {
      frag_list = [];
      fragments.set(uuid, [ t, frag_list, ch ]);
    }
    frag_list[frag_id] = frag;
    // Check for a full packet to send
    // NOTE: A full packet must have the channel set
    const n = getn(frag_list);
    if (n === nfrag) {
      fragments.delete(uuid);
      const map_prefix = Buffer.from([ 0x81 ]);
      const frag_list1 = [ map_prefix ].concat(frag_list);
      const msg_mp = Buffer.concat(frag_list1);
      // console.log(`LCM1 [${seq_id}]`, ch.toString('utf8'), msg_mp.length,
      // fragments.size);
      if (SEND_CONSISTENTLY) {
        // Wait for the interval
        // TODO: Check if ch is false
        latest.set(ch, msg_mp);
      } else {
        // Send now
        wss.broadcast(msg_mp);
      }
    }
    break;
  default:
    console.error("Bad LCM packet!");
    return;
  } // end of switch/case
  // Check if we need to prune
  if (fragments.size > 50) {
    console.log("Prune!", fragments.size);
    for (let k of fragments.keys()) {
      const tp = fragments.get(k)[0];
      console.log(k, tp, t - tp);
      const dt = t - tp;
      if (dt > 1e3) {
        fragments.delete(k);
        console.log("Deleting", k, dt);
      }
    }
    console.log("Pruned:", fragments.size);
  }
});

// WebSockets Logic
// Send multicast data to all WebSockets clients
wss.broadcast = (data) => {
  // console.log(data);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
};

// Optional ZMQ listening
if (zeromq) {
  const ZMQ_PORT = 5556;
  const subscriber = zeromq.socket('sub');
  // Receive all messages
  subscriber.subscribe('');
  subscriber.on('message', function(msg) {
    // if (msg.readUInt16BE(0) == 0x81d9) {
    //   console.log("Bad MessagePack header", msg);
    // }
    wss.broadcast(msg);
  });
  // Messages on the local machine
  subscriber.connect("tcp://localhost:" + ZMQ_PORT);
}

// Send from WebSockets client to multicast network
wss.on('connection', (ws) => {
  ws.binaryType = 'arraybuffer';
  ws.on('message', (data) => { console.log("Received", typeof data, data); });
  // ws.on('message', (data) => { mcl_transport.send(data); });
  ws.on('close', function close() { console.log('disconnected'); });
  ws.on('error', console.error);
});

// Consistenty send messages to the web socket servers
if (SEND_CONSISTENTLY) {
  setInterval(() => {
    // No need to broadcast, if there is no data
    if (latest.size === 0) {
      return;
    }
    // Broadcast each element
    // console.log("Sending consistently");
    latest.forEach(wss.broadcast);
    // Clear the dictionary
    latest.clear();
  }, CONSISTENT_RATE_MS);
}

// Create server
const server = http.createServer(
    (req, res) => { serve(req, res, finalhandler(req, res)); });

// Listen
const HTTP_PORT = 8000;
console.log("Listening on ", HTTP_PORT);
server.listen(HTTP_PORT);
