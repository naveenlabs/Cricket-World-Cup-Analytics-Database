/**
 * ROUTING MODULE: routes.js
 * -----------------------------------------------------------------------------
 * Description: Defines the application endpoints and maps them to database logic.
 * Responsibility: Manages the 'Home' dashboard and dynamic 'Query' results pages.
 * Integrates metadata for frontend rendering (Charts, Analyst Takes, etc.).
 * -----------------------------------------------------------------------------
 */

// --- DEPENDENCIES ---
const express = require('express');
const router = express.Router();
const db = require('./db');
const queries = require('./app_queries');

// --- ANALYTICS METADATA ---
// Configuration object for UI titles, descriptions, and Chart.js settings
const queryMetadata = {
    Q1: {
        title: "Q1. High-Impact Batters by Format",
        fullQuestion: "Which players exhibit the most consistent run-scoring patterns across World Cup matches, when accounting for both scoring variability and career longevity, and how does this consistency differ between ODI and T20 formats?",
        analystTake: "World Cup consistency requires not just peak performance but repeatable impact over time. In ODIs, players like Kohli and Rohit thrive through longevity-driven accumulation, where low variance and sustained volume are rewarded. T20s impose far greater volatility, making consistency statistically rarer. Kohli’s presence at the top in both formats highlights adaptability across pacing structures rather than format-specific specialisation.",
        chartConfig: { type: 'bar', labels: 'player_name', dataset: 'weighted_impact_score', label: 'Impact Score', filterColumn: 'format_name' }
    },

    Q2: {
        title: "Q2. Phase-Based Batting Productivity",
        fullQuestion: "How does batting productivity, measured by strike rate, vary across powerplay, middle, and death overs for top run-scoring batters in ODI and T20 World Cups?",
        analystTake: "ODI batting productivity peaks through controlled middle-over accumulation, where strike rate stability enables run volume without excessive risk. Death overs are selectively explosive. T20 batting displays aggression across all phases, with death overs producing extreme strike rates as batters prioritise boundary conversion. The contrast reflects structural format incentives rather than differences in batting skill.",
        chartConfig: { type: 'scatter', labels: 'player_name', dataset: ['total_runs', 'strike_rate', 'match_phase'], label: 'Phase Analysis', filterColumn: 'format_name'
        }
    },

    Q3: {
        title: "Q3. Strike Rate by Batting Order & Phase",
        fullQuestion: "How does batting strike rate vary across different innings phases for top-order and middle-order batters in ODI and T20 World Cups?",
        analystTake: "ODI strike rates exhibit a U-shaped pattern, with top-order batters anchoring early, stabilising the middle, and accelerating late. T20 strike rates increase steadily across phases, particularly for top-order batters tasked with exploiting field restrictions. Middle-order batters in both formats trade peak acceleration for stability, reflecting role-based constraints rather than inefficiency.",
        chartConfig: { type: 'line', labels: 'match_phase', dataset: 'strike_rate', label: 'Strike Rate', filterColumn: 'format_name', groupBy: 'batting_role' }
    },

    Q4: {
        title: "Q4. Powerplay Impact on Match Outcome",
        fullQuestion: "Which teams gain the largest proportion of their total runs from powerplay overs in ODI versus T20 World Cups, and how does this differ between winning and losing matches?",
        analystTake: "In ODIs, teams overly reliant on powerplay scoring often underperform, suggesting early aggression without sufficient consolidation. Winning ODI teams show narrower win–loss gaps, indicating balanced innings construction. T20 victories tolerate heavier powerplay dependence, but excessive reliance still correlates with losses, reinforcing the importance of structural balance even in short formats.",
        chartConfig: { type: 'bar', labels: 'team_name', dataset: ['PP_run_share_wins', 'PP_run_share_losses'], label: 'PP Run Share', filterColumn: 'format_name' }
    },

    Q5: {
        title: "Q5. Wicket-Taking Effectiveness by Phase",
        fullQuestion: "How does wicket-taking effectiveness vary between powerplay and death overs across formats, and which bowlers specialise in each phase?",
        analystTake: "Powerplay wickets are dominated by swing and seam bowlers, particularly in ODIs where early breakthroughs suppress run rate growth. Death overs reward precision, variation, and execution under pressure, especially in T20s. The limited overlap between powerplay and death specialists reinforces phase-specific bowling roles rather than all-format dominance.",
        chartConfig: { type: 'horizontalBar', labels: 'bowler_name', dataset: 'balls_per_wicket', label: 'Efficiency', filterColumn: 'format_name', secondaryFilter: 'match_phase' }
    },

    Q6: {
        title: "Q6. Dismissal Type Distribution",
        fullQuestion: "What dismissal types dominate in ODI and T20 World Cups, and how does their distribution vary across match phases?",
        analystTake: "Caught dismissals dominate across all phases, reflecting sustained fielding pressure as the primary wicket mechanism. T20 death overs show a marked increase in run-outs, highlighting forced errors during acceleration. ODIs maintain a more stable dismissal mix due to longer innings horizons and reduced urgency.",
        chartConfig: { type: 'stackedBar', labels: 'match_phase', dataset: 'percentage_share', groupBy: 'dismissal_type', filterColumn: 'format_name' }
    },

    Q7: {
        title: "Q7. Knockout Match Impact Players",
        fullQuestion: "Which players deliver the highest combined batting and bowling impact in World Cup knockout matches?",
        analystTake: "Knockout matches are where reputations either collapse or become permanent. Kohli’s impact score is not just the highest in the dataset, it is structurally dominant. Across formats and opposition quality, he delivers repeatable, pressure-resistant output when elimination is on the line. This is not situational luck or sample noise; it is sustained knockout superiority. While bowlers like Starc define intensity through bursts of destruction, Kohli defines control, inevitability, and composure. Statistically and contextually, he is the benchmark for big-match performance in World Cup cricket.",
        chartConfig: { type: 'lollipop', labels: 'player_name', dataset: 'total_impact_score', label: 'Impact Score' }
    },

    Q8: {
        title: "Q8. Fielding Contributions by Team",
        fullQuestion: "How do fielding contributions (catches and run-outs) differ between ODI and T20 World Cup knockout matches, and which teams benefit most from these events?",
        analystTake: "ODI knockouts reward structured catching efficiency, while T20 knockouts emphasise athletic run-outs under time pressure. Teams like England and Australia consistently extract value from fielding events, reinforcing fielding as a competitive differentiator rather than a secondary skill.",
        chartConfig: { type: 'groupedHorizontalBar', labels: 'team_name', datasets: ['catches', 'run_outs'], label: ['Catches', 'Run Outs'], filterColumn: 'format_name' }
    },

    Q9: {
        title: "Q9. Team Scoring Progression",
        fullQuestion: "How does team scoring progression across match phases differ between ODI and T20 World Cups, and what structural differences emerge between the formats?",
        analystTake: "ODI teams exhibit gradual run-rate acceleration, preserving wickets for late-innings surges. T20 teams operate flatter scoring curves with early aggression. These patterns confirm that format identity is defined by pacing philosophy and risk distribution rather than absolute scoring capability.",
        chartConfig: { type: 'line', labels: 'match_phase', dataset: 'run_rate', label: 'Run Rate', filterColumn: 'format_name', groupBy: 'team_name' }
    },

    Q10: {
        title: "Q10. Venue Scoring Patterns: The Bias Matrix",
        fullQuestion: "How do average first- and second-innings scores differ by venue in ODI and T20 World Cups, and how consistent are these scoring patterns across tournaments?",
        analystTake: "Several venues exhibit strong innings bias, particularly in ODIs where pitch deterioration impacts chasing difficulty. T20 venues display smaller innings gaps but higher volatility. Match volume helps distinguish structural venue bias from random scoring variation.",
        chartConfig: { type: 'scatter', labels: 'venue_name', dataset: ['avg_1st_innings_run', 'avg_2nd_innings_run', 'matches_played'], label: 'Scoring Pattern', filterColumn: 'format_name' }
    },

    Q11: {
        title: "Q11. Death-Over Bowling Economy",
        fullQuestion: "How does bowling economy in death overs compare between ODI and T20 World Cups, and which bowlers consistently limit scoring under end-of-innings pressure?",
        analystTake: "Death overs magnify execution errors, particularly in T20s where margins are minimal. Bowlers such as Bumrah and Starc consistently suppress scoring through precision and variation. The data suggests control and adaptability outweigh raw pace in end-of-innings scenarios.",
        chartConfig: { type: 'horizontalBar', labels: 'bowler_name', dataset: 'death_eco_rate', label: 'Economy Rate', filterColumn: 'format_name' }
    },

    Q12: {
        title: "Q12. Top-Order Stability vs Win Rate",
        fullQuestion: "How does top-order contribution to total team runs differ between ODI and T20 World Cups, and is early batting dominance more strongly associated with winning in one format than the other?",
        analystTake: "High top-order contribution strongly correlates with winning in both formats, but the effect is sharper in T20s. ODIs provide greater recovery capacity after early collapses, while T20s rarely allow regrouping. Early stability therefore acts as a force multiplier rather than a standalone predictor.",
        chartConfig: { type: 'scatter', labels: 'team_name', dataset: ['win_percentage', 'matches_played', 'top_order_contribution_band'], label: 'Success Matrix', filterColumn: 'format_name'
        }
    },

    Q13: {
        title: "Q13. Extras Contribution Analysis",
        fullQuestion: "How does the contribution of extras to total team runs vary between ODI and T20 World Cups, and how does the distribution of different extra types differ across formats?",
        analystTake: "Extras represent hidden inefficiency. T20s magnify the cost of indiscipline due to shorter innings, while ODIs dilute their impact across higher run volume. Wides dominate extra types in both formats, reinforcing control and discipline as competitive advantages.",
        chartConfig: { type: 'stackedBar', labels: 'team_name', dataset: ['wide_runs', 'no_ball_runs', 'bye_runs', 'leg_bye_runs'], label: 'Extras Breakdown', filterColumn: 'format_name' }
    },

    Q14: {
        title: "Q14. Chase Efficiency & Success",
        fullQuestion: "How does run-chase efficiency, measured as the ratio of achieved to required run rate in successful chases, differ between teams in ODI and T20 World Cups?",
        analystTake: "India stands out as the premier chasing side across both formats, showing unparalleled consistency in high-pressure games. While New Zealand relies on calculated pacing in ODIs, aggressive teams like Australia and the West Indies find more success in T20s by front-loading their scoring. Ultimately, elite performance is defined by efficient execution and the ability to dictate the tempo, whereas mid-tier teams often struggle to maintain momentum when chasing, regardless of the format.",
        chartConfig: { type: 'scatter', labels: 'team_name', dataset: ['chase_success_pct', 'rr_efficiency_ratio', 'chases_played'], label: 'Chase Performance', filterColumn: 'format_name' }
    },

    Q15: {
        title: "Q15. Momentum Impact: Run Rate Change After Wickets",
        fullQuestion: "How does the timing of wicket losses affect scoring momentum in ODI and T20 World Cups, as measured by changes in run rate immediately before and after wickets?",
        analystTake: "Wickets disrupt momentum far more severely in T20s due to limited recovery windows. ODIs absorb shocks more effectively, particularly for experienced teams. Rapid stabilisation after wickets emerges as a defining characteristic of successful sides.",
        chartConfig: { type: 'dumbbell', labels: 'team_name', dataset: ['avg_rr_before_wicket', 'avg_rr_after_wicket'], label: 'Run Rate Change', filterColumn: 'format_name' }
    }
};

// --- ROUTES ---

/**
 * @route   GET /
 * @desc    Render Dashboard Index Page
 */
router.get('/', (req, res) => {
    res.render('index', {
        questions: [
            { id: 1, title: 'High-Impact Batters by Format', category: 'Batting', summary: 'Identifies players with the most consistent run-scoring patterns across both ODI and T20 World Cups.' },
            { id: 2, title: 'Phase-Based Batting Productivity', category: 'Batting', summary: 'Analyzes how batting strike rate varies across Powerplay, Middle, and Death Overs for top batters.' },
            { id: 3, title: 'Strike Rate by Batting Order & Phase', category: 'Batting', summary: 'Compares strike rate efficiency between top-order and middle-order batters in different match phases.' },
            { id: 4, title: 'Powerplay Impact in Wins vs Losses', category: 'Strategy', summary: 'Examines the proportion of total runs scored in the Powerplay and how it correlates with the match outcome (Win/Loss).' },
            { id: 5, title: 'Wicket-Taking Effectiveness by Phase', category: 'Bowling', summary: 'Compares bowler effectiveness (wickets per ball) in Powerplay versus Death Overs across formats.' },
            { id: 6, title: 'Dismissal Type Distribution', category: 'Bowling', summary: 'Shows the frequency and distribution of different dismissal types (e.g., Caught, Bowled) across all match phases.' },
            { id: 7, title: 'Knockout Match Impact Players', category: 'Strategy', summary: 'Ranks players based on their combined normalized batting and bowling performance in Quarter-Finals, Semi-Finals, and Finals.' },
            { id: 8, title: 'Fielding Contributions by Team', category: 'Bowling', summary: 'Analyzes the contribution of catches and run-outs to total dismissals for each team in knockout matches.' },
            { id: 9, title: 'Team Scoring Progression by Phase', category: 'Strategy', summary: 'Tracks the team average run rate progression across Powerplay, Middle, and Death Overs to reveal structural differences between formats.' },
            { id: 10, title: '1st vs 2nd Innings Scoring by Venue', category: 'Strategy', summary: 'Compares average 1st and 2nd innings scores for various venues to determine run consistency and chase biases.' },
            { id: 11, title: 'Death-Over Bowling Economy', category: 'Bowling', summary: 'Ranks the most economical bowlers who consistently limit runs under pressure in the critical Death Overs.' },
            { id: 12, title: 'Top-Order Stability vs Win Rate', category: 'Strategy', summary: 'Investigates how the percentage of runs scored before the fall of the second wicket correlates with the team’s overall win rate.' },
            { id: 13, title: 'Extras Contribution by Team', category: 'Strategy', summary: 'Calculates the percentage contribution of extras (wides, no-balls, byes) to the total team runs across formats.' },
            { id: 14, title: 'Chase Efficiency & Success', category: 'Strategy', summary: 'Measures run rate efficiency (achieved vs. required) in successful run chases across all participating teams.' },
            { id: 15, title: 'Run-rate Change Around Wickets', category: 'Strategy', summary: 'Quantifies the change in run rate immediately following a wicket event compared to the period immediately preceding it.' }
        ]
    });
});

/**
 * @route   GET /query/:id
 * @desc    Dynamic Result Page for Specific SQL Queries
 */
router.get('/query/:id', (req, res) => {
    const queryIdParam = req.params.id;
    const queryKey = `Q${queryIdParam}`;
    const sql = queries[queryKey];

    if (!sql) {
        return res.status(404).send('Query not found');
    }

    db.query(sql, (err, results, fields) => {
        if (err) {
            console.error(err);
            return res.status(500).send('Database error');
        }

        const meta = queryMetadata[queryKey] || {
            title: `Analysis Results: ${queryKey}`,
            fullQuestion: "Research question not yet defined.",
            analystTake: "Detailed analysis pending.",
            chartConfig: null
        };

        const viewName = `q${queryIdParam}_results`;

        res.render(viewName, {
            queryId: queryKey,
            queryTitle: meta.title,
            fullQuestion: meta.fullQuestion,
            analystTake: meta.analystTake,
            chartConfig: meta.chartConfig,
            results,
            fields
        });
    });
});

module.exports = router;