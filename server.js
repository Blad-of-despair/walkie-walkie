const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 3000;

const clients = new Map();

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

// ========================= HTTP HANDLER =========================
function handleRequest(req, res) {
  const url = req.url === '/' ? '/index.html' : req.url;
  const filePath = path.join(__dirname, 'public', url);
  const ext = path.extname(filePath);

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
}

// ========================= WEBSOCKET LOGIC =========================
function setupWebSocket(wss) {
  wss.on('connection', (ws) => {
    const id = crypto.randomBytes(8).toString('hex');
    clients.set(ws, { id, nickname: null });

    ws.on('message', (raw) => {
      let msg;
      try { msg = JSON.parse(raw); } catch { return; }

      const client = clients.get(ws);
      if (!client) return;

      switch (msg.type) {
        case 'register':
          client.nickname = msg.nickname;
          ws.send(JSON.stringify({ type: 'registered', id }));
          broadcastUsers();
          break;
        case 'call-offer':
          forwardTo(ws, msg.target, { type: 'call-offer', from: id, fromNickname: client.nickname, sdp: msg.sdp });
          break;
        case 'call-answer':
          forwardTo(ws, msg.target, { type: 'call-answer', from: id, sdp: msg.sdp });
          break;
        case 'ice-candidate':
          forwardTo(ws, msg.target, { type: 'ice-candidate', from: id, candidate: msg.candidate });
          break;
        case 'talking-start':
          let targetNick = 'someone';
          for (const [, tc] of clients) { if (tc.id === msg.target) { targetNick = tc.nickname; break; } }
          broadcastExcept(ws, { type: 'talking-start', from: id, fromNickname: client.nickname, target: msg.target, targetNickname: targetNick });
          break;
        case 'talking-stop':
          broadcastExcept(ws, { type: 'talking-stop', from: id });
          break;
      }
    });

    ws.on('close', () => {
      clients.delete(ws);
      broadcastUsers();
    });

    ws.on('error', () => {
      clients.delete(ws);
      broadcastUsers();
    });
  });
}

function forwardTo(senderWs, targetId, msg) {
  for (const [ws, client] of clients) {
    if (client.id === targetId && ws.readyState === 1) {
      ws.send(JSON.stringify(msg));
      return;
    }
  }
  const sender = clients.get(senderWs);
  if (sender) {
    senderWs.send(JSON.stringify({ type: 'error', message: 'User disconnected or left the channel' }));
  }
}

function broadcastExcept(senderWs, msg) {
  const data = JSON.stringify(msg);
  for (const [ws] of clients) {
    if (ws !== senderWs && ws.readyState === 1) {
      ws.send(data);
    }
  }
}

function broadcastUsers() {
  const users = [];
  for (const [, c] of clients) {
    if (c.nickname) users.push({ id: c.id, nickname: c.nickname });
  }
  const msg = JSON.stringify({ type: 'userlist', users });
  for (const [ws] of clients) {
    if (ws.readyState === 1) ws.send(msg);
  }
}

// ========================= STARTUP =========================
(async () => {
  const ip = getLANIP();

  // Generate self-signed certificate if needed
  const keyPath = path.join(__dirname, 'key.pem');
  const certPath = path.join(__dirname, 'cert.pem');

  let key, cert;

  if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
    key = fs.readFileSync(keyPath);
    cert = fs.readFileSync(certPath);
  } else {
    console.log('  Generating self-signed certificate...');
    const selfsigned = require('selfsigned');
    const attrs = [
      { name: 'commonName', value: ip },
    ];
    const pems = await selfsigned.generate(attrs);
    fs.writeFileSync(keyPath, pems.private);
    fs.writeFileSync(certPath, pems.cert);
    key = pems.private;
    cert = pems.cert;
    console.log('  Certificate saved (key.pem, cert.pem).');
  }

  // HTTPS server (main - works on LAN)
  const httpsServer = https.createServer({ key, cert }, handleRequest);
  setupWebSocket(new WebSocketServer({ server: httpsServer }));
  httpsServer.listen(PORT, '0.0.0.0', () => {
    console.log('');
    console.log('  WiFi Talkie Server');
    console.log('  ' + '-'.repeat(36));
    console.log('  Local:   https://localhost:' + PORT);
    console.log('  Network: https://' + ip + ':' + PORT);
    console.log('');
    console.log('  ⚠  First-time access: browser will show a warning.');
    console.log('     Click "Advanced" → "Proceed to site" to continue.');
    console.log('');
  });

  // HTTP server on port+1 (for localhost convenience, redirects on LAN)
  const httpServer = http.createServer((req, res) => {
    if (req.headers.host && !req.headers.host.startsWith('localhost') && !req.headers.host.startsWith('127.0.0.1')) {
      res.writeHead(301, { Location: 'https://' + req.headers.host.split(':')[0] + ':' + PORT + req.url });
      res.end();
      return;
    }
    handleRequest(req, res);
  });
  setupWebSocket(new WebSocketServer({ server: httpServer }));
  httpServer.listen(PORT + 1, '0.0.0.0', () => {
    console.log('  HTTP (local):  http://localhost:' + (PORT + 1));
    console.log('');
  });
})();

// ========================= HELPERS =========================
function getLANIP() {
  const nets = require('os').networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) return net.address;
    }
  }
  return '127.0.0.1';
}
