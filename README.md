# Cricket World Cup Analytics Hub

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![MySQL](https://img.shields.io/badge/MySQL-5.7+-blue.svg)](https://www.mysql.com/)
[![Python](https://img.shields.io/badge/Python-3.6+-blue.svg)](https://www.python.org/)

> Full-stack relational database project analyzing 398 World Cup cricket matches (ODI & T20) using normalized MySQL schema (3NF), 15 advanced SQL queries, Python ETL pipeline, and interactive Node.js analytics dashboard with Chart.js visualizations.

## Overview

A comprehensive database application modeling ball-by-ball cricket match data from 166 ODI World Cup matches (2011–2023) and 232 T20 World Cup matches (2010–2024). The project demonstrates relational database design, advanced SQL analytics, ETL pipelines, and full-stack web development.

**Key Features:** Normalized 3NF MySQL schema with 10 relational tables. 15 complex SQL queries using CTEs, window functions, and multi-table joins. Python ETL pipeline for reproducible data loading. Express.js backend with EJS templating and Chart.js visualizations. Phase-based performance analysis (powerplay, middle, death overs). ODI vs T20 format comparison throughout.

## Quick Start

### Option 1: Coursera Lab (Recommended - No Setup Required)

Everything is pre-configured and ready to run.

**1. Navigate to Application**
```bash
cd app
```

**2. Start Server**
```bash
node server.js
```

**3. Open Browser**
Click the provided port link in terminal output. The dashboard will display all 15 cricket analytics queries with real-time visualizations.

---

### Option 2: Local Computer (Full Setup)

#### Prerequisites
- Node.js (v14+)
- MySQL (v5.7+)
- Python 3.6+

#### Installation

**1. Clone Repository**
```bash
git clone https://github.com/naveenlabs/Cricket-World-Cup-Analytics-Database.git
cd Cricket-World-Cup-Analytics-Database
```

**2. Setup MySQL Database**
```bash
mysql -u root -p < sql/schema.sql
```

**3. Load Cricket Data**
```bash
pip install -r requirements.txt
python scripts/load_data.py
```

**4. Configure Database Credentials**

Edit `app/db.js`:
```javascript
const connection = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'your_mysql_password',
  database: 'cricket_wc'
});
```

**5. Install Node Dependencies**
```bash
npm install
```

**6. Start Application**
```bash
npm start
```

**7. Access Dashboard**
```
http://localhost:3000
```

## Project Structure

```
Cricket-World-Cup-Analytics-Database/
├── app/                          # Node.js Web Application
│   ├── server.js                 # Express server
│   ├── db.js                     # MySQL connection
│   ├── routes.js                 # API routes
│   ├── app_queries.js            # 15 query functions
│   ├── views/                    # EJS templates
│   └── public/                   # Static assets
├── data/                         # Cricket Data (398 JSON files)
│   ├── ODI_WC/                   # ODI World Cups (166 matches)
│   └── T20_WC/                   # T20 World Cups (232 matches)
├── scripts/
│   └── load_data.py              # Python ETL
├── sql/
│   ├── schema.sql                # Database DDL
│   └── queries.sql               # 15 SQL queries
├── package.json
├── requirements.txt
└── README.md
```

## Database Schema

**10 Normalized Tables (3NF):** Format, Venue, Team (Lookup) | Player, Match (Core) | MatchTeam, Innings (Structural) | Delivery, DeliveryExtra, Wicket, FieldingEvent (Events)

**Key Relationships:** Team ↔ Match (M:N via MatchTeam) | Match → Innings (1:N) | Innings → Delivery (1:N) | Delivery → Wicket/Extra/Fielding (0..N:1)

## 15 Research Questions

**Performance & Phase Analytics (Q1–Q6):** Q1: Consistent run-scoring patterns. Q2: Batting strike rate across phases. Q3: Strike rate by batting position. Q4: Powerplay run proportion. Q5: Wicket-taking effectiveness. Q6: Dismissal distribution.

**Context, Pressure & Efficiency (Q7–Q15):** Q7: Combined batting+bowling impact. Q8: Fielding contributions. Q9: Scoring progression. Q10: Venue patterns. Q11: Death over economy. Q12: Top-order contribution. Q13: Extras contribution. Q14: Run-chase efficiency. Q15: Wicket-loss momentum.

## Technology Stack

Backend: Node.js + Express.js | Database: MySQL | Frontend: EJS + HTML + CSS | Visualizations: Chart.js | ETL: Python | API: RESTful (/query/:id)

## Dataset

Source: Cricsheet (https://cricsheet.org/matches/) | Format: JSON (ball-by-ball data) | Total: 398 World Cup matches (166 ODI + 232 T20) | Granularity: Match → Innings → Over → Delivery | Coverage: Venue, teams, players, runs, wickets, fielding events

## API Endpoints

GET / → Home page (query selection) | GET /query/:id → Execute query (id: 1-15)

## Testing Queries

**Coursera Lab:**
```bash
mysql -u root
USE cricket_wc;
source sql/queries.sql
```

**Local Computer:**
```bash
mysql -u root -p cricket_wc < sql/queries.sql
```

## Deployment

**Local Development:** npm start | Access at http://localhost:3000

**Production:** Update database credentials in app/db.js for cloud MySQL (AWS RDS, Google Cloud SQL, Azure Database).

## Assessment Coverage

**Stage 1:** Dataset identification, scope justification (398 WC matches), data quality assessment, 15 relational research questions ✅

**Stage 2:** Conceptual E/R diagram (M:N relationships), logical relational model, DDL implementation, 3NF normalization ✅

**Stage 3:** MySQL schema (10 tables), 15 complex SQL queries, Python ETL pipeline, data validation ✅

**Stage 4:** Express.js backend, EJS templating, Chart.js visualizations, responsive CSS, error handling ✅

## Security

Keep database credentials in .env (not in git). Use environment variables for sensitive data. Validate all user inputs. Use parameterized queries (already implemented).

## License

MIT License - see LICENSE file for details.

## Author

Dhanarasu Naveen | Student ID: 230655533 | Course: CM3010 - Databases and Advanced Data Techniques | University of London (via SIM Singapore)

## References

Cricsheet: https://cricsheet.org/ | MySQL: https://dev.mysql.com/doc/ | Express.js: https://expressjs.com/ | EJS: https://ejs.co/

---

**Status:** Production Ready ✅ | **Version:** 1.0.0 | **Last Updated:** May 2026
