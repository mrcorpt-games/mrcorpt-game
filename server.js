'use strict';

const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');

const app = express();
const port = Number(process.env.PORT) || 8080;
const host = process.env.HOST || '0.0.0.0';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});

app.use(express.static(path.resolve(__dirname)));

app.get('/', limiter, function(_req, res) {
  res.sendFile(path.resolve(__dirname, 'index.html'));
});

app.listen(port, host, function() {
  console.log('voxelmetaverse server listening on http://' + host + ':' + port);
});
