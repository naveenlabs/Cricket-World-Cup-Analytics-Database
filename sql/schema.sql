-- =====================================================
-- Database: Cricket World Cup Analytics
-- =====================================================

CREATE DATABASE IF NOT EXISTS cricket_wc;
USE cricket_wc;

-- =====================================================
-- Lookup Tables
-- =====================================================

CREATE TABLE Format (
    format_id INT AUTO_INCREMENT PRIMARY KEY,
    format_name VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE Venue (
    venue_id INT AUTO_INCREMENT PRIMARY KEY,
    venue_name VARCHAR(100) NOT NULL,
    venue_country VARCHAR(100) NOT NULL
);

CREATE TABLE Team (
    team_id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL UNIQUE
);

-- =====================================================
-- Core Entity Tables
-- =====================================================

CREATE TABLE Player (
    player_id INT AUTO_INCREMENT PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    team_id INT NOT NULL,
    FOREIGN KEY (team_id) REFERENCES Team(team_id)
);

CREATE TABLE `Match` (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    format_id INT NOT NULL,
    venue_id INT NOT NULL,
    match_stage VARCHAR(50) NOT NULL,
    match_date DATE NOT NULL,
    winner_team_id INT,
    result_type VARCHAR(50),
    margin_runs INT,
    margin_wickets INT,
    FOREIGN KEY (format_id) REFERENCES Format(format_id),
    FOREIGN KEY (venue_id) REFERENCES Venue(venue_id),
    FOREIGN KEY (winner_team_id) REFERENCES Team(team_id)
);

-- =====================================================
-- Associative Tables
-- =====================================================

CREATE TABLE MatchTeam (
    match_id INT NOT NULL,
    team_id INT NOT NULL,
    PRIMARY KEY (match_id, team_id),
    FOREIGN KEY (match_id) REFERENCES `Match`(match_id),
    FOREIGN KEY (team_id) REFERENCES Team(team_id)
);

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
-- Delivery-Level Tables
-- =====================================================

CREATE TABLE Delivery (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    innings_id INT NOT NULL,
    over_number INT NOT NULL,
    ball_number INT NOT NULL,
    bowler_id INT NOT NULL,
    striker_id INT NOT NULL,
    non_striker_id INT NOT NULL,
    runs_batsman INT NOT NULL DEFAULT 0,
    runs_total INT NOT NULL DEFAULT 0,
    FOREIGN KEY (innings_id) REFERENCES Innings(innings_id),
    FOREIGN KEY (bowler_id) REFERENCES Player(player_id),
    FOREIGN KEY (striker_id) REFERENCES Player(player_id),
    FOREIGN KEY (non_striker_id) REFERENCES Player(player_id),
    UNIQUE (innings_id, over_number, ball_number)
);

CREATE TABLE DeliveryExtra (
    delivery_extra_id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_id INT NOT NULL,
    extra_type VARCHAR(20) NOT NULL,
    extra_runs INT NOT NULL,
    FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id)
);

CREATE TABLE Wicket (
    wicket_id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_id INT NOT NULL,
    dismissed_player_id INT NOT NULL,
    dismissal_type VARCHAR(50) NOT NULL,
    FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id),
    FOREIGN KEY (dismissed_player_id) REFERENCES Player(player_id)
);

CREATE TABLE FieldingEvent (
    fielding_event_id INT AUTO_INCREMENT PRIMARY KEY,
    wicket_id INT NOT NULL,
    fielder_id INT NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    FOREIGN KEY (wicket_id) REFERENCES Wicket(wicket_id),
    FOREIGN KEY (fielder_id) REFERENCES Player(player_id)
);
