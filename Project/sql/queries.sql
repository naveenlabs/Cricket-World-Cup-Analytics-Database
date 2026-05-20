/* * PROJECT SQL REPOSITORY: queries.sql
 * -----------------------------------------------------------------------------
 * Description: Raw SQL implementation of the World Cup Analytics suite.
 * Architecture: Optimized for MySQL, utilizing Common Table Expressions (CTEs)
 * and Window Functions to generate advanced sports metrics.
 * -----------------------------------------------------------------------------
 */

-- =============================================================================
-- Q1: HIGH-IMPACT BATTERS (LONGEVITY VS. CONSISTENCY)
-- -----------------------------------------------------------------------------
-- Objective: Identify players who combine frequent high-impact innings 
-- with long-term participation across ODI and T20 formats.
-- Logic: Aggregates match runs, filters top scorers, and applies a 
-- logarithmic weight to reward career longevity.
-- =============================================================================

WITH player_match_runs AS (
    -- Step 1: Aggregate total runs scored by each player in every individual match
    SELECT
        f.format_name,
        m.match_id,
        p.player_id,
        p.player_name,
        SUM(d.runs_batsman) AS runs_in_match
    FROM Delivery d
    JOIN Innings i ON d.innings_id = i.innings_id
    JOIN `Match` m ON i.match_id = m.match_id
    JOIN Format f ON m.format_id = f.format_id
    JOIN Player p ON d.striker_id = p.player_id
    GROUP BY
        f.format_name,
        m.match_id,
        p.player_id,
        p.player_name
),

player_total_runs AS (
    -- Step 2: Sum up total career runs per format for all players
    SELECT
        format_name,
        player_id,
        player_name,
        SUM(runs_in_match) AS total_runs
    FROM player_match_runs
    GROUP BY
        format_name,
        player_id,
        player_name
),

top_run_scorers AS (
    -- Step 3: Rank players to isolate the top 15 run-getters per format
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY total_runs DESC
        ) AS run_rank
    FROM player_total_runs
),

player_impact AS (
    -- Step 4: Calculate impact metrics (50+ for ODI, 30+ for T20) for top scorers
    SELECT
        pmr.format_name,
        pmr.player_id,
        pmr.player_name,
        COUNT(pmr.match_id) AS matches_played,
        SUM(
            CASE
                WHEN (pmr.format_name = 'ODI' AND pmr.runs_in_match >= 50)
                  OR (pmr.format_name = 'T20' AND pmr.runs_in_match >= 30)
                THEN 1
                ELSE 0
            END
        ) AS high_impact_innings,
        AVG(pmr.runs_in_match) AS avg_runs_per_match
    FROM player_match_runs pmr
    JOIN top_run_scorers trs
        ON pmr.player_id = trs.player_id
       AND pmr.format_name = trs.format_name
    WHERE trs.run_rank <= 15
    GROUP BY
        pmr.format_name,
        pmr.player_id,
        pmr.player_name
),

ranked_players AS (
    -- Step 5: Apply logarithmic weighting to high-impact innings based on matches played
    SELECT
        format_name,
        player_name,
        matches_played,
        high_impact_innings,
        ROUND(high_impact_innings / matches_played, 3) AS impact_consistency_rate,
        ROUND(
            high_impact_innings * LOG(matches_played),
            3
        ) AS weighted_impact_score,
        ROUND(avg_runs_per_match, 2) AS avg_runs_per_match,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY
                (high_impact_innings * LOG(matches_played)) DESC,
                avg_runs_per_match DESC
        ) AS impact_rank
    FROM player_impact
    WHERE matches_played >= 5
)

-- Final Output: Retrieve top 5 high-impact consistent performers per format
SELECT
    format_name,
    player_name,
    matches_played,
    high_impact_innings,
    impact_consistency_rate,
    weighted_impact_score,
    avg_runs_per_match
FROM ranked_players
WHERE impact_rank <= 5
ORDER BY
    format_name,
    impact_rank;

-- =============================================================================
-- Q2: PHASE-BASED BATTING PRODUCTIVITY (EFFICIENCY MAPPING)
-- -----------------------------------------------------------------------------
-- Objective: Determine which elite batters are most productive in specific 
-- match phases (Powerplay, Middle, Death) across ODI and T20 World Cups.
-- Logic: Maps deliveries to over-ranges, calculates Strike Rate, and filters 
-- for the top 15 overall run-scorers to identify "phase specialists."
-- =============================================================================

WITH player_total_runs AS (
    -- Step 1: Calculate lifetime runs per format to identify high-volume batters
    SELECT
        f.format_name,
        p.player_id,
        p.player_name,
        SUM(d.runs_batsman) AS total_runs
    FROM Delivery d
    JOIN Innings i ON d.innings_id = i.innings_id
    JOIN `Match` m ON i.match_id = m.match_id
    JOIN Format f ON m.format_id = f.format_id
    JOIN Player p ON d.striker_id = p.player_id
    GROUP BY
        f.format_name,
        p.player_id,
        p.player_name
),

elite_batters AS (
    -- Step 2: Rank players by total runs to create a pool of "Elite" batters (Top 15)
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY total_runs DESC
        ) AS run_rank
    FROM player_total_runs
),

phase_deliveries AS (
    -- Step 3: Categorize every ball into a match phase based on over number and format
    -- ODI: PP (1-10), Middle (11-40), Death (41+)
    -- T20: PP (1-6), Middle (7-15), Death (16+)
    SELECT
        f.format_name,
        CASE
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 1 AND 10 THEN 'Powerplay'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 11 AND 40 THEN 'Middle Overs'
            WHEN f.format_name = 'ODI' AND d.over_number >= 41 THEN 'Death Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 7 AND 15 THEN 'Middle Overs'
            WHEN f.format_name = 'T20' AND d.over_number >= 16 THEN 'Death Overs'
        END AS match_phase,
        p.player_name,
        t.team_name,
        m.match_id,
        d.runs_batsman,
        1 AS ball_faced
    FROM Delivery d
    JOIN Innings i ON d.innings_id = i.innings_id
    JOIN `Match` m ON i.match_id = m.match_id
    JOIN Format f ON m.format_id = f.format_id
    JOIN Player p ON d.striker_id = p.player_id
    JOIN Team t ON p.team_id = t.team_id
    JOIN elite_batters eb
        ON eb.player_id = p.player_id
       AND eb.format_name = f.format_name
    WHERE eb.run_rank <= 15
),

phase_aggregates AS (
    -- Step 4: Aggregate runs and balls per phase to calculate Strike Rate (SR)
    SELECT
        format_name,
        match_phase,
        player_name,
        team_name,
        COUNT(DISTINCT match_id) AS matches_played,
        SUM(runs_batsman) AS total_runs,
        SUM(ball_faced) AS balls_faced,
        ROUND((SUM(runs_batsman) / SUM(ball_faced)) * 100, 2) AS strike_rate
    FROM phase_deliveries
    WHERE match_phase IS NOT NULL
    GROUP BY
        format_name,
        match_phase,
        player_name,
        team_name
),

ranked_phase_players AS (
    -- Step 5: Rank players within each phase and apply minimum sample size (balls faced) filters
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY format_name, match_phase
            ORDER BY total_runs DESC
        ) AS phase_rank
    FROM phase_aggregates
    WHERE
        (
            format_name = 'ODI' AND
            (
                (match_phase = 'Powerplay' AND balls_faced >= 30)
             OR (match_phase = 'Middle Overs' AND balls_faced >= 70)
             OR (match_phase = 'Death Overs' AND balls_faced >= 30)
            )
        )
     OR
        (
            format_name = 'T20' AND
            (
                (match_phase = 'Powerplay' AND balls_faced >= 18)
             OR (match_phase = 'Middle Overs' AND balls_faced >= 30)
             OR (match_phase = 'Death Overs' AND balls_faced >= 12)
            )
        )
)

-- Final Output: Retrieve the top 5 run-scorers for every match phase in each format
SELECT
    format_name,
    match_phase,
    player_name,
    team_name,
    matches_played,
    total_runs,
    balls_faced,
    strike_rate
FROM ranked_phase_players
WHERE phase_rank <= 5
ORDER BY
    format_name,
    match_phase,
    phase_rank;

-- =============================================================================
-- Q3: STRIKE RATE BY BATTING ORDER & PHASE (ROLE-BASED PACING)
-- -----------------------------------------------------------------------------
-- Objective: Analyze how Strike Rate evolves across match phases for Top Order 
-- (1-3) vs Middle Order (4-6) batters in ODI and T20 World Cups.
-- Logic: Uses ball indices to determine entry order, maps players to roles, 
-- and aggregates performance across Powerplay, Middle, and Death overs.
-- =============================================================================

WITH batter_entry AS (
    -- Step 1: Identify the exact ball (index) where each player faced their first delivery
    -- used to determine the batting order/position.
    SELECT
        i.innings_id,
        d.striker_id AS player_id,
        MIN(d.over_number * 6 + d.ball_number) AS first_ball
    FROM Delivery d
    JOIN Innings i ON d.innings_id = i.innings_id
    GROUP BY
        i.innings_id,
        d.striker_id
),

batting_position AS (
    -- Step 2: Rank players by their entry ball to assign a standard batting position (1-11)
    SELECT
        innings_id,
        player_id,
        ROW_NUMBER() OVER (
            PARTITION BY innings_id
            ORDER BY first_ball
        ) AS batting_position
    FROM batter_entry
),

phase_runs AS (
    -- Step 3: Aggregate runs and balls per player, per match phase, and per role
    SELECT
        f.format_name,
        p.player_id,
        p.player_name,
        t.team_name,
        bp.batting_position,
        CASE
            WHEN d.over_number <= 6 AND f.format_name = 'T20' THEN 'Powerplay'
            WHEN d.over_number <= 10 AND f.format_name = 'ODI' THEN 'Powerplay'
            WHEN (f.format_name = 'T20' AND d.over_number BETWEEN 7 AND 16)
              OR (f.format_name = 'ODI' AND d.over_number BETWEEN 11 AND 40)
            THEN 'Middle Overs'
            ELSE 'Death Overs'
        END AS match_phase,
        SUM(d.runs_batsman) AS runs_scored,
        COUNT(*) AS balls_faced
    FROM Delivery d
    JOIN Innings i ON d.innings_id = i.innings_id
    JOIN `Match` m ON i.match_id = m.match_id
    JOIN Format f ON m.format_id = f.format_id
    JOIN Player p ON d.striker_id = p.player_id
    JOIN Team t ON p.team_id = t.team_id
    JOIN batting_position bp
        ON bp.innings_id = i.innings_id
       AND bp.player_id = p.player_id
    GROUP BY
        f.format_name,
        p.player_id,
        p.player_name,
        t.team_name,
        bp.batting_position,
        match_phase
),

role_phase_sr AS (
    -- Step 4: Group data into "Top Order" (1-3) and "Middle Order" (4-6)
    -- and calculate the final Strike Rate per role per phase.
    SELECT
        format_name,
        CASE
            WHEN batting_position BETWEEN 1 AND 3 THEN 'Top Order'
            WHEN batting_position BETWEEN 4 AND 6 THEN 'Middle Order'
        END AS batting_role,
        match_phase,
        SUM(runs_scored) AS total_runs,
        SUM(balls_faced) AS total_balls,
        ROUND(SUM(runs_scored) * 100.0 / SUM(balls_faced), 2) AS strike_rate
    FROM phase_runs
    WHERE batting_position BETWEEN 1 AND 6
    GROUP BY
        format_name,
        batting_role,
        match_phase
)

-- Final Output: Comparative Strike Rate matrix for format, phase, and batting role
SELECT
    format_name,
    batting_role,
    match_phase,
    total_runs,
    total_balls,
    strike_rate
FROM role_phase_sr
ORDER BY
    format_name,
    CASE match_phase
        WHEN 'Powerplay' THEN 1
        WHEN 'Middle Overs' THEN 2
        WHEN 'Death Overs' THEN 3
    END,
    CASE batting_role
        WHEN 'Top Order' THEN 1
        WHEN 'Middle Order' THEN 2
    END;

-- =============================================================================
-- Q4: POWERPLAY IMPACT ON MATCH OUTCOME (THE WINNING MARGIN)
-- -----------------------------------------------------------------------------
-- Objective: Calculate the percentage contribution of Powerplay runs to total 
-- team scores, comparing successful (Wins) and unsuccessful (Losses) matches.
-- Logic: Aggregates ball-by-ball runs (including extras), identifies format-
-- specific Powerplay windows, and joins with match winners to determine correlation.
-- =============================================================================

WITH team_ball_runs AS (
    -- Step 1: Calculate total runs per delivery by summing batsman runs and extras.
    -- Grouping ensures we capture 'extra' records linked to specific deliveries.
    SELECT
        f.format_name,
        m.match_id,
        t.team_id,
        t.team_name,
        d.over_number,
        d.runs_batsman
        + COALESCE(SUM(de.extra_runs), 0) AS runs_scored
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    LEFT JOIN DeliveryExtra de
        ON d.delivery_id = de.delivery_id
    GROUP BY
        f.format_name,
        m.match_id,
        t.team_id,
        t.team_name,
        d.delivery_id,
        d.over_number,
        d.runs_batsman
),

team_phase_runs AS (
    -- Step 2: Aggregate total innings runs and isolate runs scored in Powerplay.
    -- ODI Powerplay: Overs 1-10 | T20 Powerplay: Overs 1-6.
    SELECT
        format_name,
        match_id,
        team_id,
        team_name,
        SUM(runs_scored) AS total_runs,
        SUM(
            CASE
                WHEN format_name = 'ODI' AND over_number BETWEEN 1 AND 10 THEN runs_scored
                WHEN format_name = 'T20' AND over_number BETWEEN 1 AND 6 THEN runs_scored
                ELSE 0
            END
        ) AS powerplay_runs
    FROM team_ball_runs
    GROUP BY
        format_name,
        match_id,
        team_id,
        team_name
),

team_powerplay_share AS (
    -- Step 3: Determine match outcome (Win/Loss) for each batting team
    -- and calculate the 'Powerplay Share' (PP Runs / Total Runs).
    SELECT
        tpr.format_name,
        tpr.team_name,
        CASE
            WHEN m.winner_team_id = tpr.team_id THEN 'Win'
            ELSE 'Loss'
        END AS match_outcome,
        tpr.powerplay_runs / tpr.total_runs AS powerplay_share
    FROM team_phase_runs tpr
    JOIN `Match` m
        ON tpr.match_id = m.match_id
    WHERE tpr.total_runs > 0
)

-- Final Output: Aggregate averages to show if winners rely more on Powerplay scoring.
SELECT
    format_name,
    team_name,

    COUNT(CASE WHEN match_outcome = 'Win' THEN 1 END) AS wins,
    ROUND(
        AVG(CASE WHEN match_outcome = 'Win' THEN powerplay_share END) * 100,
        2
    ) AS `PP_run_share_wins (%)`,

    COUNT(CASE WHEN match_outcome = 'Loss' THEN 1 END) AS losses,
    ROUND(
        AVG(CASE WHEN match_outcome = 'Loss' THEN powerplay_share END) * 100,
        2
    ) AS `PP_run_share_losses (%)`

FROM team_powerplay_share
GROUP BY
    format_name,
    team_name
ORDER BY
    format_name,
    `PP_run_share_wins (%)` DESC;

-- =============================================================================
-- Q5: BOWLING EFFECTIVENESS BY PHASE (PHASE SPECIALISTS)
-- -----------------------------------------------------------------------------
-- Objective: Analyze wicket-taking efficiency in the Powerplay and Death overs 
-- across formats to identify phase-specific specialists.
-- Logic: Isolates phase-specific deliveries, filters out run-outs (not credited 
-- to bowler), and calculates the "Balls Per Wicket" (Bowling Strike Rate) for 
-- bowlers with a significant sample size (10+ matches).
-- =============================================================================

WITH phase_deliveries AS (
    -- Step 1: Identify and categorize deliveries into specific high-impact phases.
    -- JOIN MatchTeam ensuring we pull the bowling team (not the batting team).
    SELECT
        f.format_name,
        m.match_id,
        p.player_id AS bowler_id,
        p.player_name AS bowler_name,
        t.team_name,

        CASE
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 1 AND 10 THEN 'Powerplay'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 41 AND 50 THEN 'Death Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 16 AND 20 THEN 'Death Overs'
        END AS match_phase,

        w.wicket_id,
        w.dismissal_type
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Player p
        ON d.bowler_id = p.player_id
    JOIN MatchTeam mt
        ON mt.match_id = m.match_id
       AND mt.team_id <> i.batting_team_id
    JOIN Team t
        ON mt.team_id = t.team_id

    LEFT JOIN Wicket w
        ON d.delivery_id = w.delivery_id
    WHERE
        (
            (f.format_name = 'ODI' AND (d.over_number BETWEEN 1 AND 10 OR d.over_number BETWEEN 41 AND 50))
            OR
            (f.format_name = 'T20' AND (d.over_number BETWEEN 1 AND 6 OR d.over_number BETWEEN 16 AND 20))
        )
),

bowler_phase_stats AS (
    -- Step 2: Aggregate phase data per bowler. 
    -- Wickets are counted only if they are bowler-credited (excludes run outs).
    SELECT
        format_name,
        match_phase,
        bowler_id,
        bowler_name,
        team_name,
        COUNT(*) AS balls_bowled,
        COUNT(DISTINCT match_id) AS matches_played,
        SUM(
            CASE
                WHEN wicket_id IS NOT NULL
                 AND dismissal_type <> 'run out'
                THEN 1 ELSE 0
            END
        ) AS wickets
    FROM phase_deliveries
    WHERE match_phase IS NOT NULL
    GROUP BY
        format_name,
        match_phase,
        bowler_id,
        bowler_name,
        team_name
),

filtered_bowler_stats AS (
    -- Step 3: Calculate the efficiency KPI (Balls per Wicket).
    -- Filter for a minimum of 10 matches to ensure statistical significance.
    SELECT
        *,
        ROUND(balls_bowled / NULLIF(wickets, 0), 2) AS balls_per_wicket
    FROM bowler_phase_stats
    WHERE
        wickets > 0
        AND matches_played >= 10
),

ranked_specialists AS (
    -- Step 4: Rank the specialists within each format and phase.
    -- Priority: Highest total wickets, then best (lowest) balls-per-wicket.
    SELECT
        format_name,
        match_phase,
        bowler_name,
        team_name,
        matches_played,
        wickets,
        balls_bowled,
        balls_per_wicket,
        ROW_NUMBER() OVER (
            PARTITION BY format_name, match_phase
            ORDER BY wickets DESC, balls_per_wicket ASC
        ) AS phase_rank
    FROM filtered_bowler_stats
)

-- Final Output: Retrieve the elite specialists (Top 5) per phase.
SELECT
    format_name,
    match_phase,
    bowler_name,
    team_name,
    matches_played,
    wickets,
    balls_bowled,
    balls_per_wicket
FROM ranked_specialists
WHERE phase_rank <= 5
ORDER BY
    format_name,
    CASE match_phase
        WHEN 'Powerplay' THEN 1
        WHEN 'Death Overs' THEN 2
    END,
    phase_rank;

-- =============================================================================
-- Q6: DISMISSAL TYPE DISTRIBUTION (WICKET MECHANISMS)
-- -----------------------------------------------------------------------------
-- Objective: Identify which dismissal types dominate in ODI vs T20 World Cups 
-- and how their frequency shifts across the three match phases.
-- Logic: Maps every wicket to a match phase, aggregates the counts per 
-- dismissal type, and uses a Window Function to calculate the percentage 
-- share of each type within that specific phase and format.
-- =============================================================================

WITH phase_wickets AS (
    -- Step 1: Link Wicket events to Match phases.
    -- We use over numbers to categorize wickets into Powerplay, Middle, and Death.
    SELECT
        f.format_name,

        CASE
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 1 AND 10 THEN 'Powerplay'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 11 AND 40 THEN 'Middle Overs'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 41 AND 50 THEN 'Death Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 7 AND 15 THEN 'Middle Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 16 AND 20 THEN 'Death Overs'
        END AS match_phase,

        w.dismissal_type
    FROM Wicket w
    JOIN Delivery d
        ON w.delivery_id = d.delivery_id
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
),

dismissal_counts AS (
    -- Step 2: Aggregate the number of wickets for each dismissal type per phase.
    -- Filters out null phases (e.g., if a match ended prematurely).
    SELECT
        format_name,
        match_phase,
        dismissal_type,
        COUNT(*) AS wickets
    FROM phase_wickets
    WHERE match_phase IS NOT NULL
    GROUP BY
        format_name,
        match_phase,
        dismissal_type
),

dismissal_distribution AS (
    -- Step 3: Calculate the relative percentage share of each dismissal type.
    -- The OVER clause partitions by phase to ensure percentages sum to 100% per phase.
    SELECT
        format_name,
        match_phase,
        dismissal_type,
        wickets,
        ROUND(
            wickets * 100.0 /
            SUM(wickets) OVER (PARTITION BY format_name, match_phase),
            2
        ) AS percentage_share
    FROM dismissal_counts
)

-- Final Output: Sorted by format, chronological phase order, and volume of wickets.
SELECT
    format_name,
    match_phase,
    dismissal_type,
    wickets,
    percentage_share
FROM dismissal_distribution
ORDER BY
    format_name,
    CASE match_phase
        WHEN 'Powerplay' THEN 1
        WHEN 'Middle Overs' THEN 2
        WHEN 'Death Overs' THEN 3
    END,
    wickets DESC;

-- =============================================================================
-- Q7: KNOCKOUT MATCH IMPACT PLAYERS (BIG-GAME PERFORMERS)
-- -----------------------------------------------------------------------------
-- Objective: Rank players by their total statistical impact specifically in 
-- high-pressure knockout matches (Quarter Finals, Semi Finals, and Finals).
-- Logic: Normalizes batting and bowling stats per match (0 to 1 scale) relative 
-- to the best performance in that specific match. This allows batting and 
-- bowling contributions to be summed into a single "Impact Score."
-- =============================================================================

WITH knockout_matches AS (
    -- Step 1: Isolate the matches that occurred during the knockout stages.
    SELECT
        m.match_id
    FROM `Match` m
    WHERE m.match_stage IN ('Quarter Final', 'Semi Final', 'Final')
),

batting_stats AS (
    -- Step 2: Aggregate runs scored by every player in these knockout matches.
    SELECT
        km.match_id,
        d.striker_id AS player_id,
        t.team_name,
        SUM(d.runs_batsman) AS runs_scored
    FROM knockout_matches km
    JOIN Innings i
        ON km.match_id = i.match_id
    JOIN Delivery d
        ON i.innings_id = d.innings_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    GROUP BY
        km.match_id,
        d.striker_id,
        t.team_name
),

batting_normalised AS (
    -- Step 3: Use a Window Function to divide a player's runs by the match maximum.
    -- Result: 1.0 = top scorer of that match; 0.5 = scored half of the top score.
    SELECT
        match_id,
        player_id,
        team_name,
        runs_scored / MAX(runs_scored) OVER (PARTITION BY match_id) AS batting_score
    FROM batting_stats
),

bowling_stats AS (
    -- Step 4: Aggregate bowler-credited wickets in these knockout matches.
    SELECT
        km.match_id,
        d.bowler_id AS player_id,
        t.team_name,
        COUNT(*) AS wickets_taken
    FROM knockout_matches km
    JOIN Innings i
        ON km.match_id = i.match_id
    JOIN Delivery d
        ON i.innings_id = d.innings_id
    JOIN Wicket w
        ON d.delivery_id = w.delivery_id
    JOIN MatchTeam mt
        ON mt.match_id = km.match_id
       AND mt.team_id <> i.batting_team_id
    JOIN Team t
        ON mt.team_id = t.team_id
    WHERE w.dismissal_type <> 'run out'
    GROUP BY
        km.match_id,
        d.bowler_id,
        t.team_name
),

bowling_normalised AS (
    -- Step 5: Normalize wickets taken per match.
    -- Result: 1.0 = took the most wickets in that match.
    SELECT
        match_id,
        player_id,
        team_name,
        wickets_taken / MAX(wickets_taken) OVER (PARTITION BY match_id) AS bowling_score
    FROM bowling_stats
),

match_impact AS (
    -- Step 6: Perform a complex join to merge batting and bowling scores.
    -- COALESCE ensures players who only batted or only bowled are still included.
    SELECT
        COALESCE(b.match_id, w.match_id) AS match_id,
        COALESCE(b.player_id, w.player_id) AS player_id,
        COALESCE(b.team_name, w.team_name) AS team_name,
        COALESCE(b.batting_score, 0) AS batting_score,
        COALESCE(w.bowling_score, 0) AS bowling_score
    FROM batting_normalised b
    LEFT JOIN bowling_normalised w
        ON b.match_id = w.match_id
       AND b.player_id = w.player_id

    UNION ALL

    SELECT
        w.match_id,
        w.player_id,
        w.team_name,
        0 AS batting_score,
        w.bowling_score
    FROM bowling_normalised w
    WHERE NOT EXISTS (
        SELECT 1
        FROM batting_normalised b
        WHERE b.match_id = w.match_id
          AND b.player_id = w.player_id
    )
),

player_impact AS (
    -- Step 7: Aggregate the normalized scores across all knockouts a player played.
    SELECT
        p.player_name,
        mi.team_name,
        COUNT(DISTINCT mi.match_id) AS knockout_matches_played,
        ROUND(SUM(mi.batting_score), 2) AS total_batting_impact,
        ROUND(SUM(mi.bowling_score), 2) AS total_bowling_impact,
        ROUND(SUM(mi.batting_score + mi.bowling_score), 2) AS total_impact_score
    FROM match_impact mi
    JOIN Player p
        ON mi.player_id = p.player_id
    GROUP BY
        p.player_name,
        mi.team_name
),

final_ranked AS (
    -- Step 8: Categorize players based on the source of their impact points.
    SELECT
        player_name,
        team_name,
        knockout_matches_played,
        total_batting_impact,
        total_bowling_impact,
        total_impact_score,
        CASE
            WHEN total_batting_impact / total_impact_score >= 0.70 THEN 'Batter'
            WHEN total_bowling_impact / total_impact_score >= 0.70 THEN 'Bowler'
            ELSE 'All-rounder'
        END AS role
    FROM player_impact
)

-- Final Output: Top 10 All-Time Knockout Performers by Impact Score.
SELECT
    player_name,
    team_name,
    role,
    knockout_matches_played,
    total_impact_score
FROM final_ranked
ORDER BY
    total_impact_score DESC
LIMIT 10;

-- =============================================================================
-- Q8: FIELDING CONTRIBUTIONS BY TEAM (DEFENSIVE PRESSURE)
-- -----------------------------------------------------------------------------
-- Objective: Compare fielding contributions (catches and run-outs) between ODI 
-- and T20 World Cups, identifying teams that benefit most from defensive events.
-- Logic: Isolates fielding dismissals in knockout matches, aggregates events per 
-- team, and calculates averages per match to determine defensive efficiency.
-- =============================================================================

WITH knockout_matches AS (
    -- Step 1: Identify all knockout matches and their respective formats.
    SELECT
        m.match_id,
        f.format_name
    FROM `Match` m
    JOIN Format f
        ON m.format_id = f.format_id
    WHERE m.match_stage IN ('Quarter Final', 'Semi Final', 'Final')
),

team_knockout_matches AS (
    -- Step 2: Create a base map of teams and the knockout matches they participated in.
    -- This ensures teams with zero fielding events are still present in the list.
    SELECT
        km.format_name,
        mt.team_id,
        t.team_name,
        km.match_id
    FROM knockout_matches km
    JOIN MatchTeam mt
        ON km.match_id = mt.match_id
    JOIN Team t
        ON mt.team_id = t.team_id
),

fielding_events AS (
    -- Step 3: Isolate dismissals where fielders are primary contributors.
    -- Note: We filter for 'caught' and 'run out' events.
    SELECT
        km.format_name,
        mt.team_id,
        km.match_id,
        w.dismissal_type
    FROM knockout_matches km
    JOIN Innings i
        ON km.match_id = i.match_id
    JOIN Delivery d
        ON i.innings_id = d.innings_id
    JOIN Wicket w
        ON d.delivery_id = w.delivery_id
    JOIN MatchTeam mt
        ON mt.match_id = km.match_id
       AND mt.team_id <> i.batting_team_id
    WHERE w.dismissal_type IN ('caught', 'caught and bowled', 'run out')
),

team_fielding_aggregates AS (
    -- Step 4: Sum up the specific fielding events (Catches vs Run Outs) for each team.
    -- JOIN back to the team_knockout_matches base to maintain accurate match counts.
    SELECT
        tkm.format_name,
        tkm.team_name,
        COUNT(DISTINCT tkm.match_id) AS matches_played,
        SUM(
            CASE
                WHEN fe.dismissal_type IN ('caught', 'caught and bowled')
                THEN 1 ELSE 0
            END
        ) AS catches,
        SUM(
            CASE
                WHEN fe.dismissal_type = 'run out'
                THEN 1 ELSE 0
            END
        ) AS run_outs
    FROM team_knockout_matches tkm
    LEFT JOIN fielding_events fe
        ON tkm.match_id = fe.match_id
       AND tkm.team_id = fe.team_id
    GROUP BY
        tkm.format_name,
        tkm.team_name
),

ranked_teams AS (
    -- Step 5: Calculate averages per match and rank teams per format.
    -- Total Fielding Dismissals acts as the primary ranking metric.
    SELECT
        format_name,
        team_name,
        matches_played,
        COALESCE(catches, 0) AS catches,
        COALESCE(run_outs, 0) AS run_outs,
        ROUND(COALESCE(catches, 0) / matches_played, 2) AS avg_catches_per_match,
        ROUND(COALESCE(run_outs, 0) / matches_played, 2) AS avg_runouts_per_match,
        (COALESCE(catches, 0) + COALESCE(run_outs, 0)) AS total_fielding_dismissals,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY (COALESCE(catches, 0) + COALESCE(run_outs, 0)) DESC
        ) AS team_rank
    FROM team_fielding_aggregates
)

-- Final Output: Retrieve the top 5 clinical fielding teams per format.
SELECT
    format_name,
    team_name,
    matches_played,
    catches,
    run_outs,
    avg_catches_per_match,
    avg_runouts_per_match,
    total_fielding_dismissals
FROM ranked_teams
WHERE team_rank <= 5
ORDER BY
    format_name,
    total_fielding_dismissals DESC;

-- =============================================================================
-- Q9: TEAM SCORING PROGRESSION (FORMAT PACING PATTERNS)
-- -----------------------------------------------------------------------------
-- Objective: Analyze how team scoring rates (Runs Per Over) evolve through 
-- match phases and compare the structural pacing differences between 
-- ODI and T20 World Cups.
-- Logic: Identifies the top 5 run-scoring teams per format, categorizes 
-- deliveries into phases, and calculates the Run Rate (total runs / total overs) 
-- for each segment.
-- =============================================================================

WITH team_total_runs AS (
    -- Step 1: Aggregate total career runs per format for every team.
    -- This provides the basis for selecting the most consistent batting units.
    SELECT
        f.format_name,
        t.team_id,
        t.team_name,
        SUM(d.runs_total) AS total_runs
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    GROUP BY
        f.format_name,
        t.team_id,
        t.team_name
),

ranked_teams AS (
    -- Step 2: Rank the teams based on their total run volume within each format.
    SELECT
        format_name,
        team_id,
        team_name,
        total_runs,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY total_runs DESC
        ) AS team_rank
    FROM team_total_runs
),

top_teams AS (
    -- Step 3: Filter for the Top 5 "Elite" batting teams to focus the analysis.
    SELECT
        format_name,
        team_id,
        team_name
    FROM ranked_teams
    WHERE team_rank <= 5
),

phase_runs AS (
    -- Step 4: Map every delivery to a phase and aggregate runs and overs faced.
    -- Overs faced is calculated by counting unique combinations of innings and over numbers.
    SELECT
        f.format_name,
        t.team_name,

        CASE
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 1 AND 10 THEN 'Powerplay'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 11 AND 40 THEN 'Middle Overs'
            WHEN f.format_name = 'ODI' AND d.over_number BETWEEN 41 AND 50 THEN 'Death Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 7 AND 15 THEN 'Middle Overs'
            WHEN f.format_name = 'T20' AND d.over_number BETWEEN 16 AND 20 THEN 'Death Overs'
        END AS match_phase,

        SUM(d.runs_total) AS phase_runs,
        COUNT(DISTINCT CONCAT(i.innings_id, '-', d.over_number)) AS overs_faced
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    JOIN top_teams tt
        ON tt.team_id = t.team_id
       AND tt.format_name = f.format_name
    GROUP BY
        f.format_name,
        t.team_name,
        match_phase
)

-- Final Output: Calculate Run Rate and sort chronologically by match phase.
SELECT
    format_name,
    team_name,
    match_phase,
    ROUND(phase_runs / overs_faced, 2) AS run_rate
FROM phase_runs
WHERE match_phase IS NOT NULL
ORDER BY
    format_name,
    team_name,
    CASE match_phase
        WHEN 'Powerplay' THEN 1
        WHEN 'Middle Overs' THEN 2
        WHEN 'Death Overs' THEN 3
    END;

-- =============================================================================
-- Q10: VENUE SCORING PATTERNS (THE BIAS MATRIX)
-- -----------------------------------------------------------------------------
-- Objective: Compare average team scoring between the 1st and 2nd innings 
-- across different stadiums in ODI and T20 World Cups.
-- Logic: Normalizes venue names, aggregates total runs for every innings, 
-- and calculates format-specific averages per venue to highlight scoring bias.
-- =============================================================================

WITH innings_scores AS (
    -- Step 1: Calculate total runs for every 1st and 2nd innings played.
    -- SUBSTRING_INDEX is used to create a 'canonical' venue name, stripping 
    -- specific ground sections to group by the stadium as a whole.
    SELECT
        f.format_name,

        TRIM(SUBSTRING_INDEX(v.venue_name, ',', 1)) AS canonical_venue,

        v.venue_country,
        i.innings_number,
        m.match_id,
        SUM(d.runs_total) AS innings_runs
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Venue v
        ON m.venue_id = v.venue_id
    WHERE
        i.innings_number IN (1, 2)
    GROUP BY
        f.format_name,
        canonical_venue,
        v.venue_country,
        i.innings_number,
        m.match_id
),

venue_innings_avg AS (
    -- Step 2: Aggregate the scores to find the average per innings per venue.
    -- GROUP_CONCAT handles cases where a venue name might be associated with 
    -- multiple recorded country strings in the source data.
    SELECT
        format_name,
        canonical_venue AS venue_name,

        GROUP_CONCAT(
            DISTINCT venue_country
            ORDER BY venue_country
            SEPARATOR ' / '
        ) AS venue_country,

        AVG(CASE WHEN innings_number = 1 THEN innings_runs END) AS avg_1st_innings_run,
        AVG(CASE WHEN innings_number = 2 THEN innings_runs END) AS avg_2nd_innings_run,
        COUNT(DISTINCT match_id) AS matches_played
    FROM innings_scores
    GROUP BY
        format_name,
        canonical_venue
)

-- Final Output: A comparative leaderboard of stadiums and their scoring profiles.
SELECT
    format_name,
    venue_name,
    venue_country,
    ROUND(avg_1st_innings_run, 2) AS avg_1st_innings_run,
    ROUND(avg_2nd_innings_run, 2) AS avg_2nd_innings_run,
    matches_played
FROM venue_innings_avg
ORDER BY
    format_name,
    venue_name;
    
-- =============================================================================
-- Q11: DEATH-OVER BOWLING ECONOMY (THE MISER'S LIST)
-- -----------------------------------------------------------------------------
-- Objective: Compare bowling economy rates in the final overs of ODI and T20 
-- World Cups to identify bowlers who consistently limit scoring under pressure.
-- Logic: Filters deliveries for the "Death" phase (ODI: 41-50, T20: 16-20), 
-- aggregates runs and balls, and calculates the Economy Rate (Runs per 6 balls).
-- =============================================================================

WITH death_over_deliveries AS (
    -- Step 1: Isolate deliveries bowled in the final phase of each format.
    -- Ensures we only look at bowlers competing against the batting team.
    SELECT
        f.format_name,
        m.match_id,
        p.player_id AS bowler_id,
        p.player_name AS bowler_name,
        t.team_name,
        d.runs_total,
        w.wicket_id,
        w.dismissal_type
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Player p
        ON d.bowler_id = p.player_id
    JOIN MatchTeam mt
        ON mt.match_id = m.match_id
       AND mt.team_id <> i.batting_team_id
    JOIN Team t
        ON mt.team_id = t.team_id
    LEFT JOIN Wicket w
        ON d.delivery_id = w.delivery_id
    WHERE
        (
            (f.format_name = 'ODI' AND d.over_number BETWEEN 41 AND 50)
            OR
            (f.format_name = 'T20' AND d.over_number BETWEEN 16 AND 20)
        )
),

bowler_death_stats AS (
    -- Step 2: Aggregate statistical totals for the death phase per bowler.
    -- Wickets exclude run-outs as they do not factor into bowling skill metrics.
    SELECT
        format_name,
        bowler_id,
        bowler_name,
        team_name,
        COUNT(*) AS balls_bowled,
        SUM(runs_total) AS runs_conceded,
        COUNT(DISTINCT match_id) AS matches_played,
        SUM(
            CASE
                WHEN wicket_id IS NOT NULL
                 AND dismissal_type <> 'run out'
                THEN 1 ELSE 0
            END
        ) AS wickets
    FROM death_over_deliveries
    GROUP BY
        format_name,
        bowler_id,
        bowler_name,
        team_name
),

filtered_bowlers AS (
    -- Step 3: Calculate the Death Economy Rate.
    -- Filters for longevity (10+ matches) and realistic economy caps.
    SELECT
        *,
        ROUND((runs_conceded * 6.0) / balls_bowled, 2) AS death_eco_rate
    FROM bowler_death_stats
    WHERE
        matches_played >= 10
        AND balls_bowled > 0
        AND (runs_conceded * 6.0) / balls_bowled < 10
),

ranked_bowlers AS (
    -- Step 4: Rank bowlers per format by Economy Rate (Primary) and Wickets (Secondary).
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY format_name
            ORDER BY death_eco_rate ASC, wickets DESC
        ) AS format_rank
    FROM filtered_bowlers
)

-- Final Output: Top 10 most economical death bowlers per format.
SELECT
    format_name,
    bowler_name,
    team_name,
    matches_played,
    runs_conceded,
    balls_bowled,
    wickets,
    death_eco_rate
FROM ranked_bowlers
WHERE format_rank <= 10
ORDER BY
    format_name,
    death_eco_rate ASC,
    wickets DESC;

-- =============================================================================
-- Q12: TOP-ORDER STABILITY VS WIN RATE
-- -----------------------------------------------------------------------------
-- Objective: Analyze how team winning probability varies with top-order 
-- stability (defined as the runs scored before the loss of the 2nd wicket).
-- Logic: Uses Window Functions to calculate a running total of runs and 
-- wickets per innings. It سپس categorizes matches into stability bands 
-- (Low, Moderate, High) to calculate win percentages for each team.
-- =============================================================================

WITH wicket_progression AS (
    -- Step 1: Use Window Functions to create a ball-by-ball running total 
    -- of runs and a running count of wickets for every innings.
    SELECT
        i.match_id,
        i.batting_team_id,
        f.format_name,
        d.delivery_id,

        SUM(d.runs_total) OVER (
            PARTITION BY i.match_id, i.batting_team_id
            ORDER BY d.delivery_id
        ) AS cumulative_runs,

        COUNT(w.delivery_id) OVER (
            PARTITION BY i.match_id, i.batting_team_id
            ORDER BY d.delivery_id
        ) AS cumulative_wickets

    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    LEFT JOIN Wicket w
        ON d.delivery_id = w.delivery_id
),

runs_upto_2nd_wicket AS (
    -- Step 2: Extract the maximum runs achieved before the 2nd wicket fell.
    -- This represents the "Top Order Contribution" for that match.
    SELECT
        match_id,
        batting_team_id,
        format_name,
        MAX(cumulative_runs) AS runs_before_2nd_wicket
    FROM wicket_progression
    WHERE cumulative_wickets < 2
    GROUP BY
        match_id,
        batting_team_id,
        format_name
),

total_team_runs AS (
    -- Step 3: Calculate the total runs scored in the entire innings 
    -- to use as a denominator for percentage calculations.
    SELECT
        i.match_id,
        i.batting_team_id,
        SUM(d.runs_total) AS total_runs
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    GROUP BY
        i.match_id,
        i.batting_team_id
),

match_level_contribution AS (
    -- Step 4: Calculate the percentage of the total score provided 
    -- by the top order (before 2 wickets fell).
    SELECT
        r.match_id,
        r.batting_team_id,
        r.format_name,
        (r.runs_before_2nd_wicket / NULLIF(t.total_runs, 0)) * 100
            AS pct_top_order_runs
    FROM runs_upto_2nd_wicket r
    JOIN total_team_runs t
        ON r.match_id = t.match_id
       AND r.batting_team_id = t.batting_team_id
),

categorized_matches AS (
    -- Step 5: Assign each match performance into a Stability Band.
    -- Low: <30% | Moderate: 30-60% | High: >60%
    SELECT
        match_id,
        batting_team_id,
        format_name,
        CASE
            WHEN pct_top_order_runs < 30 THEN 'Low (<30%)'
            WHEN pct_top_order_runs <= 60 THEN 'Moderate (30–60%)'
            ELSE 'High (>60%)'
        END AS top_order_contribution_band
    FROM match_level_contribution
)

-- Final Output: Calculate Win Percentage per team, per band, per format.
-- Filtered for teams with at least 3 matches in a specific band for reliability.
SELECT
    cm.format_name,
    t.team_name,
    cm.top_order_contribution_band,

    COUNT(*) AS matches_played,

    SUM(
        CASE
            WHEN m.winner_team_id = cm.batting_team_id
            THEN 1 ELSE 0
        END
    ) AS matches_won,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN m.winner_team_id = cm.batting_team_id
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS win_percentage

FROM categorized_matches cm
JOIN `Match` m
    ON cm.match_id = m.match_id
JOIN Team t
    ON cm.batting_team_id = t.team_id

GROUP BY
    cm.format_name,
    t.team_name,
    cm.top_order_contribution_band

HAVING COUNT(*) >= 3

ORDER BY
    cm.format_name,
    t.team_name,
    cm.top_order_contribution_band;

-- =============================================================================
-- Q13: EXTRAS CONTRIBUTION ANALYSIS (INDISCIPLINE ANALYSIS)
-- -----------------------------------------------------------------------------
-- Objective: Identify the proportion of total runs in ODI and T20 World Cups 
-- that come from extras, breaking them down by type (Wides, No-Balls, etc.).
-- Logic: Aggregates match participation, total team runs, and specific extra 
-- types from the DeliveryExtra table to calculate averages and percentage shares.
-- =============================================================================

WITH team_matches AS (
    -- Step 1: Count total distinct matches played by each team per format.
    -- This serves as the denominator for calculating 'average extras per match'.
    SELECT
        f.format_name,
        t.team_id,
        t.team_name,
        COUNT(DISTINCT m.match_id) AS matches_played
    FROM `Match` m
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN MatchTeam mt
        ON m.match_id = mt.match_id
    JOIN Team t
        ON mt.team_id = t.team_id
    GROUP BY
        f.format_name,
        t.team_id,
        t.team_name
),

team_runs AS (
    -- Step 2: Sum all runs (batting + extras) scored BY the team per format.
    -- This is used to calculate the percentage contribution of extras.
    SELECT
        f.format_name,
        t.team_id,
        SUM(d.runs_total) AS total_team_runs
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    GROUP BY
        f.format_name,
        t.team_id
),

team_extras AS (
    -- Step 3: Pivot and aggregate specific extra types from the DeliveryExtra table.
    -- Categorizes runs into Wides, No-Balls, Byes, and Leg-Byes.
    SELECT
        f.format_name,
        t.team_id,

        SUM(CASE WHEN de.extra_type = 'wides'   THEN de.extra_runs ELSE 0 END) AS wide_runs,
        SUM(CASE WHEN de.extra_type = 'noballs' THEN de.extra_runs ELSE 0 END) AS no_ball_runs,
        SUM(CASE WHEN de.extra_type = 'byes'    THEN de.extra_runs ELSE 0 END) AS bye_runs,
        SUM(CASE WHEN de.extra_type = 'legbyes' THEN de.extra_runs ELSE 0 END) AS leg_bye_runs,

        SUM(
            CASE
                WHEN de.extra_type IN ('wides', 'noballs', 'byes', 'legbyes')
                THEN de.extra_runs
                ELSE 0
            END
        ) AS total_extras
    FROM DeliveryExtra de
    JOIN Delivery d
        ON de.delivery_id = d.delivery_id
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Team t
        ON i.batting_team_id = t.team_id
    GROUP BY
        f.format_name,
        t.team_id
)

-- Final Output: Calculate average extras per match and the % impact on the score.
-- COALESCE is used to handle teams that conceded zero extras in specific categories.
SELECT
    tm.format_name,
    tm.team_name,
    tm.matches_played,

    COALESCE(te.wide_runs, 0)     AS wide_runs,
    COALESCE(te.no_ball_runs, 0) AS no_ball_runs,
    COALESCE(te.bye_runs, 0)      AS bye_runs,
    COALESCE(te.leg_bye_runs, 0)  AS leg_bye_runs,
    COALESCE(te.total_extras, 0)  AS total_extras,

    ROUND(
        COALESCE(te.total_extras, 0) / tm.matches_played,
        2
    ) AS avg_extras_per_match,

    ROUND(
        COALESCE(te.total_extras, 0) * 100.0 / tr.total_team_runs,
        2
    ) AS extras_pct_of_team_runs

FROM team_matches tm
LEFT JOIN team_extras te
    ON tm.team_id = te.team_id
   AND tm.format_name = te.format_name
LEFT JOIN team_runs tr
    ON tm.team_id = tr.team_id
   AND tm.format_name = tr.format_name

WHERE tm.matches_played >= 3
  AND tr.total_team_runs > 0

ORDER BY
    tm.format_name,
    extras_pct_of_team_runs DESC;

-- =============================================================================
-- Q14: CHASE EFFICIENCY & SUCCESS (THE MASTERY MATRIX)
-- -----------------------------------------------------------------------------
-- Objective: Analyze how efficiently teams convert run chases into wins. 
-- Measures success rate and the 'Efficiency Ratio' (Achieved RR vs Required RR).
-- Logic: Isolates 2nd innings wins, calculates runs scored per legal delivery, 
-- and compares the actual scoring pace to a theoretical baseline to determine 
-- which teams chase with the most composure and speed.
-- =============================================================================

WITH chase_level AS (
    -- Step 1: Filter for successful chases (2nd innings wins).
    -- Calculates total runs and identifies 'legal balls' (excludes wides/no-balls) 
    -- to accurately determine the achieved Run Rate.
    SELECT
        f.format_name,
        m.match_id,
        ia2.batting_team_id AS team_id,
        SUM(d.runs_batsman + IFNULL(de.extra_runs, 0)) AS runs_scored,
        COUNT(
            CASE
                WHEN de.extra_type IS NULL
                     OR de.extra_type NOT IN ('wides', 'noballs')
                THEN 1
            END
        ) AS legal_balls
    FROM `Match` m
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Innings ia2
        ON m.match_id = ia2.match_id
       AND ia2.innings_number = 2
    JOIN Delivery d
        ON d.innings_id = ia2.innings_id
    LEFT JOIN DeliveryExtra de
        ON d.delivery_id = de.delivery_id
    WHERE
        ia2.batting_team_id = m.winner_team_id
    GROUP BY
        f.format_name,
        m.match_id,
        ia2.batting_team_id
),

team_aggregate AS (
    -- Step 2: Aggregate successful chase data at the team level.
    -- avg_achieved_rr: The actual pace the team maintained.
    -- avg_required_rr: A baseline required rate (derived from total target / full overs).
    SELECT
        format_name,
        team_id,
        COUNT(*) AS successful_chases,

        AVG((runs_scored / legal_balls) * 6) AS avg_achieved_rr,

        AVG(
            CASE
                WHEN format_name = 'ODI'
                    THEN (runs_scored / 300) * 6
                WHEN format_name = 'T20'
                    THEN (runs_scored / 120) * 6
            END
        ) AS avg_required_rr
    FROM chase_level
    GROUP BY
        format_name,
        team_id
),

chases_played AS (
    -- Step 3: Count total attempts at chasing (all 2nd innings) 
    -- to calculate the Win/Loss success percentage.
    SELECT
        f.format_name,
        ia2.batting_team_id AS team_id,
        COUNT(DISTINCT m.match_id) AS chases_played
    FROM `Match` m
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Innings ia2
        ON m.match_id = ia2.match_id
       AND ia2.innings_number = 2
    GROUP BY
        f.format_name,
        ia2.batting_team_id
),

match_counts AS (
    -- Step 4: Aggregate total match participation for context.
    SELECT
        f.format_name,
        i.batting_team_id AS team_id,
        COUNT(DISTINCT m.match_id) AS total_matches_played
    FROM `Match` m
    JOIN Format f
        ON m.format_id = f.format_id
    JOIN Innings i
        ON m.match_id = i.match_id
    GROUP BY
        f.format_name,
        i.batting_team_id
)

-- Final Output: Calculate Chase Success % and the RR Efficiency Ratio.
-- Efficiency Ratio > 1.0 indicates a team that scores faster than the required pace.
SELECT
    ta.format_name,
    t.team_name,
    mc.total_matches_played,
    cp.chases_played,
    ta.successful_chases,

    ROUND(
        (ta.successful_chases / cp.chases_played) * 100,
        2
    ) AS chase_success_pct,

    ROUND(ta.avg_required_rr, 2) AS avg_required_rr,
    ROUND(ta.avg_achieved_rr, 2) AS avg_achieved_rr,

    ROUND(
        ta.avg_achieved_rr / ta.avg_required_rr,
        3
    ) AS rr_efficiency_ratio

FROM team_aggregate ta
JOIN chases_played cp
    ON ta.format_name = cp.format_name
   AND ta.team_id = cp.team_id
JOIN match_counts mc
    ON ta.format_name = mc.format_name
   AND ta.team_id = mc.team_id
JOIN Team t
    ON ta.team_id = t.team_id

WHERE ta.successful_chases >= 5

ORDER BY
    ta.format_name,
    chase_success_pct DESC,
    rr_efficiency_ratio DESC;

-- =============================================================================
-- Q15: MOMENTUM IMPACT (THE WICKET CRASH)
-- -----------------------------------------------------------------------------
-- Objective: Analyze how wicket loss affects scoring momentum by comparing 
-- the Run Rate (RR) immediately before and after a dismissal.
-- Logic: Uses ball indices to create a window around every wicket event 
-- (24 balls for ODI, 12 balls for T20). It calculates the average RR change 
-- per team to identify who recovers best vs. who collapses under pressure.
-- =============================================================================

WITH wicket_events AS (
    -- Step 1: Identify the exact delivery (ball index) where every wicket fell.
    -- The ball_index provides a linear timeline for the entire innings.
    SELECT
        f.format_name,
        m.match_id,
        i.innings_id,
        i.batting_team_id AS team_id,
        d.delivery_id,
        d.over_number,
        d.ball_number,
        (d.over_number * 6 + d.ball_number) AS ball_index
    FROM Wicket w
    JOIN Delivery d
        ON w.delivery_id = d.delivery_id
    JOIN Innings i
        ON d.innings_id = i.innings_id
    JOIN `Match` m
        ON i.match_id = m.match_id
    JOIN Format f
        ON m.format_id = f.format_id
),

delivery_runs AS (
    -- Step 2: Map total runs (batting + extras) to every unique ball index.
    -- This allows us to perform look-ahead and look-back calculations.
    SELECT
        i.innings_id,
        (d.over_number * 6 + d.ball_number) AS ball_index,
        (d.runs_batsman + IFNULL(de.extra_runs, 0)) AS runs_scored
    FROM Delivery d
    JOIN Innings i
        ON d.innings_id = i.innings_id
    LEFT JOIN DeliveryExtra de
        ON d.delivery_id = de.delivery_id
),

wicket_windows AS (
    -- Step 3: Aggregate runs and balls in the window surrounding each wicket.
    -- ODI Window: 4 overs (24 balls) | T20 Window: 2 overs (12 balls).
    SELECT
        we.format_name,
        we.team_id,

        -- Runs and balls in the window immediately BEFORE the wicket
        SUM(
            CASE
                WHEN dr.ball_index BETWEEN
                     we.ball_index - CASE WHEN we.format_name = 'ODI' THEN 24 ELSE 12 END
                     AND we.ball_index - 1
                THEN dr.runs_scored
            END
        ) AS runs_before,

        COUNT(
            CASE
                WHEN dr.ball_index BETWEEN
                     we.ball_index - CASE WHEN we.format_name = 'ODI' THEN 24 ELSE 12 END
                     AND we.ball_index - 1
                THEN 1
            END
        ) AS balls_before,

        -- Runs and balls in the window immediately AFTER the wicket
        SUM(
            CASE
                WHEN dr.ball_index BETWEEN
                     we.ball_index + 1
                     AND we.ball_index + CASE WHEN we.format_name = 'ODI' THEN 24 ELSE 12 END
                THEN dr.runs_scored
            END
        ) AS runs_after,

        COUNT(
            CASE
                WHEN dr.ball_index BETWEEN
                     we.ball_index + 1
                     AND we.ball_index + CASE WHEN we.format_name = 'ODI' THEN 24 ELSE 12 END
                THEN 1
            END
        ) AS balls_after
    FROM wicket_events we
    JOIN delivery_runs dr
        ON we.innings_id = dr.innings_id
    GROUP BY
        we.format_name,
        we.team_id,
        we.ball_index
)

-- Final Output: Calculate average Run Rate before/after and the net change.
-- Sorted by avg_rr_change ASC to highlight the largest "momentum crashes" first.
SELECT
    ww.format_name,
    t.team_name,

    ROUND(
        AVG((ww.runs_before / NULLIF(ww.balls_before, 0)) * 6),
        2
    ) AS avg_rr_before_wicket,

    ROUND(
        AVG((ww.runs_after / NULLIF(ww.balls_after, 0)) * 6),
        2
    ) AS avg_rr_after_wicket,

    ROUND(
        AVG(
            ((ww.runs_after / NULLIF(ww.balls_after, 0)) -
             (ww.runs_before / NULLIF(ww.balls_before, 0))
            ) * 6
        ),
        2
    ) AS avg_rr_change,

    COUNT(*) AS wicket_events

FROM wicket_windows ww
JOIN Team t
    ON ww.team_id = t.team_id

WHERE
    ww.balls_before > 0
    AND ww.balls_after > 0

GROUP BY
    ww.format_name,
    t.team_name

ORDER BY
    ww.format_name,
    avg_rr_change ASC;
