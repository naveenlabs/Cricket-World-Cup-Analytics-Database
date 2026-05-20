/**
 * DATABASE CONNECTION CONFIGURATION: db.js
 * -----------------------------------------------------------------------------
 * Description: Establishes a connection to the MySQL database instance.
 * Responsibility: Manages authentication, connection initialization, 
 * and handles fatal connection errors.
 * -----------------------------------------------------------------------------
 */

// --- DEPENDENCIES ---
const mysql = require('mysql2');

// --- CONNECTION CONFIGURATION ---
// Defines the credentials and parameters for the MySQL connection
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'cricket_wc'
});

// --- CONNECTION EXECUTION ---
// Attempts to establish the link with the database server
db.connect((err) => {
    if (err) {
        // Log the error and terminate the process if connection fails
        console.error('❌ Database connection failed:', err.message);
        process.exit(1);
    }
    console.log('✅ Connected to MySQL database');
});

// --- MODULE EXPORT ---
// Exports the connection object for use in other parts of the application
module.exports = db;