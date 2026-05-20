// app/server.js
const express = require('express');
const path = require('path');

const routes = require('./routes');

const app = express();
const PORT = 3000;

// Set view engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Static files (CSS)
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.use('/', routes);

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
