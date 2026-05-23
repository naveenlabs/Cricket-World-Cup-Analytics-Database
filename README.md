# Cricket World Cup Analytics Hub

[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Node.js](https://img.shields.io/badge/node.js-18+-blue)]()
[![MySQL](https://img.shields.io/badge/mysql-5.7+-orange)]()
[![Python](https://img.shields.io/badge/python-3.6+-blue)]()
[![Status](https://img.shields.io/badge/status-complete-success)]()

## Overview 

A full-stack relational database project analyzing 398 World Cup cricket matches (ODI & T20 formats). Features normalized MySQL schema (3NF), 15 advanced SQL queries using CTEs and window functions, Python ETL pipeline, and interactive Node.js analytics dashboard with Chart.js visualizations.

**Module:** CM3010 Databases and Advanced Data Techniques  
**Dataset:** 166 ODI World Cup matches (2011–2023) | 232 T20 World Cup matches (2010–2024)  
**Data Source:** Cricsheet (ball-by-ball JSON) | **Total:** 398 World Cup matches

## Key Results

| Aspect | Coverage | Details |
|--------|----------|---------|
| **Database** | 10 Normalized Tables | 3NF schema with referential integrity |
| **Queries** | 15 Analytical Queries | CTEs, window functions, multi-table joins |
| **Architecture** | Full-Stack Application | Express.js backend + EJS frontend + Chart.js visualizations |
| **Data Granularity** | Ball-by-Ball | Match → Innings → Delivery level analysis |

## What's Inside

**Node.js Web Application** (`app/server.js`):
- Express.js REST API with 15 query endpoints (/query/:id)
- EJS dynamic templating for result visualization
- Chart.js integration for interactive data charts
- Responsive CSS design for cross-device compatibility

**MySQL Database** (`sql/schema.sql`):
- 10 normalized tables: Format, Venue, Team, Player, Match, MatchTeam, Innings, Delivery, DeliveryExtra, Wicket, FieldingEvent
- MatchTeam M:N associative entity resolving team-match relationships
- Referential integrity via foreign keys and unique constraints
- Optimized indexes for analytical query performance

**SQL Queries** (`sql/queries.sql`):
- Q1–Q6: Performance & Phase Analytics (strike rate, powerplay impact, dismissals)
- Q7–Q15: Context & Efficiency (combined impact, fielding, venue patterns, momentum)
- Advanced techniques: CTEs, window functions (ROW_NUMBER, RANK, DENSE_RANK), complex aggregations

**Python ETL** (`scripts/load_data.py`):
- Parses 398 Cricsheet JSON match files
- Normalizes hierarchical data into relational tables
- Validates data integrity and handles edge cases
- Reproducible pipeline for consistent data loading

**Cricket Data** (`data/` directory):
- ODI_WC: 2011 (49), 2015 (42), 2019 (36), 2023 (39) matches
- T20_WC: 2010 (25), 2012 (25), 2014 (32), 2016 (27), 2021 (40), 2022 (39), 2024 (44) matches

## Quick Start

### Option 1: Coursera Lab (Recommended - Pre-Configured)

Everything is already set up. Just run the application.

[Open Coursera Lab](https://hub.labs.coursera.org:443/connect/sharedlznbekpu?forceRefresh=false&path=%2F%3Ffolder%3D%2Fhome%2Fcoder%2Fproject&sessionMigrationMode=shadow)

```bash
cd app
node server.js
# Open browser at port shown in terminal output
```

### Option 2: Local Computer (Full Setup)

**Prerequisites:** Node.js (v14+) | MySQL (v5.7+) | Python 3.6+

```bash
# 1. Clone repository
git clone https://github.com/naveenlabs/Cricket-World-Cup-Analytics-Database.git
cd Cricket-World-Cup-Analytics-Database

# 2. Create database
mysql -u root -p < sql/schema.sql

# 3. Load data
pip install -r requirements.txt
python scripts/load_data.py

# 4. Configure credentials
# Edit app/db.js and update MySQL password

# 5. Install dependencies
npm install

# 6. Start application
npm start

# 7. Access dashboard
# http://localhost:3000
```

## 15 Research Questions

**Performance & Phase Analytics (Q1–Q6)**
- Q1: Consistent run-scoring patterns across World Cup matches
- Q2: Batting strike rate across powerplay/middle/death phases
- Q3: Strike rate variation by batting position
- Q4: Powerplay run proportion (winning vs losing teams)
- Q5: Wicket-taking effectiveness by phase
- Q6: Dismissal type distribution across phases

**Context, Pressure & Efficiency (Q7–Q15)**
- Q7: Combined batting + bowling impact (knockout matches)
- Q8: Fielding contributions (catches, run-outs)
- Q9: Team scoring progression by phase
- Q10: Venue-specific scoring patterns
- Q11: Bowling economy in death overs
- Q12: Top-order contribution % vs winning
- Q13: Extras contribution to total runs
- Q14: Run-chase efficiency ratio
- Q15: Wicket-loss timing impact on momentum

## Database Schema

**Normalization:** 3NF (Third Normal Form)

**Lookup Tables:** Format, Venue, Team (static reference data)

**Core Entities:** Player, Match (entity definitions)

**Structural Tables:** MatchTeam (M:N resolver), Innings (hierarchy)

**Event Tables:** Delivery, DeliveryExtra, Wicket, FieldingEvent (ball-by-ball transactions)

**Key Relationships:** Team ↔ Match (M:N via MatchTeam) | Match → Innings (1:N) | Innings → Delivery (1:N) | Delivery → Wicket/Extra/Fielding (0..N:1)

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | Node.js + Express.js |
| **Database** | MySQL |
| **Frontend** | EJS + HTML + CSS |
| **Visualizations** | Chart.js |
| **ETL** | Python |
| **API** | RESTful (/query/:id) |

## Methodology Highlights

**Data Quality:** 398 authentic World Cup matches from Cricsheet with ball-by-ball granularity. Controlled scope (World Cups only) for high-stakes competitive context and meaningful cross-team comparability.

**Schema Design:** Normalized 3NF with separation of lookup data (Format, Venue, Team) from transactional events (Delivery, Wicket, Extra). Associative MatchTeam entity resolves M:N team-match relationships cleanly.

**Query Complexity:** Advanced SQL techniques including CTEs for recursive/non-recursive common table expressions, window functions for ranking and aggregation, multi-table joins across 8–10 tables, conditional logic via CASE statements, and group-by aggregations with HAVING clauses.

**Validation:** SQL queries tested on both ODI and T20 datasets separately. Format-specific phase definitions (powerplay, middle, death) enforced in queries. Performance metrics calculated for fair algorithm-independent evaluation.

**Reproducibility:** Fixed random seed for consistency. Separate SQL files for schema and queries. Python ETL script handles JSON parsing and normalization. All 398 matches included with no sampling.

## Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /` | Query selection hub (15 queries listed) |
| `GET /query/:id` | Execute query (id: 1–15), return results + visualization |

## Experimental Sections

- Conceptual E/R diagram (real-world relationships including M:N Team–Match)
- Logical relational model (implementation-ready schema with PK/FK)
- Normalization validation (1NF, 2NF, 3NF proofs)
- Query performance analysis (CTEs vs subqueries, aggregation efficiency)
- Visualization of results (data tables, Chart.js charts, format comparisons)
- Phase-based analysis (powerplay vs middle vs death overs)
- Cross-format comparison (ODI vs T20 structural differences)

## Author

**Dhanarasu Naveen**  
Computer Science | University of London (via SIM Singapore)  
Specialization: Artificial Intelligence & Machine Learning

## License

MIT License

## References

Cricsheet: https://cricsheet.org/ | MySQL: https://dev.mysql.com/doc/ | Express.js: https://expressjs.com/ | EJS: https://ejs.co/

---
