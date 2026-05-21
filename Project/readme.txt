World Cup Cricket Analytics – Project README

==============================
Project Structure
==============================
app/        Node.js web application (Express server and routes)
sql/        Database schema and analytical SQL queries
scripts/    Python ETL script (JSON → MySQL)
data/       Cricsheet World Cup match data (ODI and T20)
report/     Final coursework PDF

==============================
Database Access and Testing
==============================
The MySQL database is already created and populated in this Coursera Lab.

To inspect or test analytical SQL queries:

1. Start MySQL:
   mysql -u root

2. Select the project database:
   USE cricket_wc;

3. Run analytical queries from:
   sql/queries.sql

==============================
Running the Web Application
==============================
The Node.js application is located in the `app` directory.

1. Navigate to the application directory:
   cd app

2. Start the server:
   node server.js

3. Open the application in a browser using the local port shown in the terminal.
