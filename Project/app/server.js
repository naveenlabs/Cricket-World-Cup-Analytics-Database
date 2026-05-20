/**
 * PROJECT SERVER CONFIGURATION: server.js
 * -----------------------------------------------------------------------------
 * Description: Main entry point for the Express application.
 * Responsibility: Sets up the view engine, configures static middleware,
 * mounts application routes, and initializes the network listener.
 * -----------------------------------------------------------------------------
 */

// --- DEPENDENCIES ---
const express = require('express');
const path = require('path');

// --- MODULES ---
const routes = require('./routes');

// --- INITIALIZATION ---
const app = express();
const PORT = 3000;

// --- VIEW ENGINE SETUP ---
// Configures EJS as the template engine and sets the views directory path
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// --- MIDDLEWARE ---
// Serves static assets (CSS, Images, JS) from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// --- ROUTE MOUNTING ---
// Delegates all root-level requests to the external routes module
app.use('/', routes);

// --- SERVER STARTUP ---
app.listen(PORT, () => {
    console.log(`🚀 Server running at http://localhost:${PORT}`);
});