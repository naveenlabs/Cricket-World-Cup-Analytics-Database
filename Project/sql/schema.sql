/* * DATABASE SCHEMA: Cricket World Cup Analytics
 * -----------------------------------------------------------------------------
 * Description: Relational structure for tracking multi-format World Cup data.
 * Architecture: normalized Snowflake Schema design to ensure data integrity
 * from high-level Match details down to ball-by-ball Delivery level.
 * -----------------------------------------------------------------------------
 */

CREATE DATABASE IF NOT EXISTS cricket_wc;
USE cricket_wc;

-- =====================================================
-- 1. LOOKUP TABLES (Static Metadata)
-- =====================================================

-- Stores match formats (e.g., 'ODI', 'T20')
CREATE TABLE Format (
    format_id INT AUTO_INCREMENT PRIMARY KEY,
    format_name VARCHAR(20) NOT NULL UNIQUE
);

-- Stores stadium information and locations
CREATE TABLE Venue (
    venue_id INT AUTO_INCREMENT PRIMARY KEY,
    venue_name VARCHAR(100) NOT NULL,
    venue_country VARCHAR(100) NOT NULL
);

-- Stores participating national teams
CREATE TABLE Team (
    team_id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL UNIQUE
);

-- =====================================================
-- 2. CORE ENTITIES
-- =====================================================

-- Individual player profiles linked to their respective teams
CREATE TABLE Player (
    player_id INT AUTO_INCREMENT PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    team_id INT NOT NULL,
    FOREIGN KEY (team_id) REFERENCES Team(team_id)
);

-- Primary Match record tracking stages, dates, and outcomes
CREATE TABLE `Match` (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    format_id INT NOT NULL,
    venue_id INT NOT NULL,
    match_stage VARCHAR(50) NOT NULL, -- e.g., Group, Semi Final, Final
    match_date DATE NOT NULL,
    winner_team_id INT,
    result_type VARCHAR(50), -- e.g., normal, tie, no result
    margin_runs INT,
    margin_wickets INT,
    FOREIGN KEY (format_id) REFERENCES Format(format_id),
    FOREIGN KEY (venue_id) REFERENCES Venue(venue_id),
    FOREIGN KEY (winner_team_id) REFERENCES Team(team_id)
);

-- =====================================================
-- 3. ASSOCIATIVE & STRUCTURAL TABLES
-- =====================================================

-- Many-to-Many mapping to link two teams to a single match
CREATE TABLE MatchTeam (
    match_id INT NOT NULL,
    team_id INT NOT NULL,
    PRIMARY KEY (match_id, team_id),
    FOREIGN KEY (match_id) REFERENCES `Match`(match_id),
    FOREIGN KEY (team_id) REFERENCES Team(team_id)
);

-- Bridges Matches and Deliveries; tracks batting order (1st/2nd Innings)
CREATE TABLE Innings (
    innings_id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT NOT NULL,
    batting_team_id INT NOT NULL,
    innings_number INT NOT NULL,
    FOREIGN KEY (match_id) REFERENCES `Match`(match_id),
    FOREIGN KEY (batting_team_id) REFERENCES Team(team_id),
    UNIQUE (match_id, innings_number)
);

-- =====================================================
-- 4. TRANSACTIONAL DATA (Ball-by-Ball)
-- =====================================================

-- The most granular table: tracks every legal and illegal ball bowled
CREATE TABLE Delivery (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    innings_id INT NOT NULL,
    over_number INT NOT NULL,
    ball_number INT NOT NULL,
    bowler_id INT NOT NULL,
    striker_id INT NOT NULL,
    non_striker_id INT NOT NULL,
    runs_batsman INT NOT NULL DEFAULT 0, -- Runs off the bat
    runs_total INT NOT NULL DEFAULT 0,   -- Total runs including extras
    FOREIGN KEY (innings_id) REFERENCES Innings(innings_id),
    FOREIGN KEY (bowler_id) REFERENCES Player(player_id),
    FOREIGN KEY (striker_id) REFERENCES Player(player_id),
    FOREIGN KEY (non_striker_id) REFERENCES Player(player_id),
    UNIQUE (innings_id, over_number, ball_number)
);

-- Sub-table for Deliveries: tracks types of extras (Wides, No Balls, etc.)
CREATE TABLE DeliveryExtra (
    delivery_extra_id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_id INT NOT NULL,
    extra_type VARCHAR(20) NOT NULL,
    extra_runs INT NOT NULL,
    FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id)
);

-- Records wicket events linked to a specific delivery
CREATE TABLE Wicket (
    wicket_id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_id INT NOT NULL,
    dismissed_player_id INT NOT NULL,
    dismissal_type VARCHAR(50) NOT NULL,
    FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id),
    FOREIGN KEY (dismissed_player_id) REFERENCES Player(player_id)
);

-- Records fielder involvement in a wicket (Catches, Run Outs, Stumpings)
CREATE TABLE FieldingEvent (
    fielding_event_id INT AUTO_INCREMENT PRIMARY KEY,
    wicket_id INT NOT NULL,
    fielder_id INT NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    FOREIGN KEY (wicket_id) REFERENCES Wicket(wicket_id),
    FOREIGN KEY (fielder_id) REFERENCES Player(player_id)
);