const express = require('express');
const router = express.Router();

const db = require('./db');
const queries = require('./app_queries');

// ----------------------------
// METADATA: Analyst's Take & Chart Config
// ----------------------------
const queryMetadata = {
  Q1: {
    title: "Q1. High-Impact Batters by Format",
    fullQuestion: "Which players exhibit the most consistent run-scoring patterns across World Cup matches?",
    analystTake: "Identifies true 'anchors' and 'finishers'. Kohli is a dual-format giant, while Buttler (T20) and Rohit (ODI) show specialized dominance.",
    chartConfig: { type: 'bar', labels: 'player_name', dataset: 'weighted_impact_score', label: 'Impact Score', filterColumn: 'format_name' }
  },
  
  Q2: {
    title: "Q2. Phase-Based Batting Productivity",
    fullQuestion: "How does batting strike rate and run volume vary across powerplay, middle, and death overs for the top run-scorers?",
    analystTake: "This chart reveals the distinct 'gears' of cricket. In T20 Death Overs, strike rates explode (e.g., Buttler near 200), identifying pure 'Finishers'. Contrast this with ODI Middle Overs, where 'Builders' like Kohli accumulate massive volume at steady strike rates (~85).",
    chartConfig: { 
      type: 'scatter', 
      labels: 'player_name', 
      dataset: ['total_runs', 'strike_rate', 'match_phase'], 
      label: 'Phase Analysis', 
      filterColumn: 'format_name' 
    } 
  },

  Q3: {
    title: "Q3. Strike Rate by Batting Order & Phase",
    fullQuestion: "How does strike rate vary across phases for top-order and middle-order batters?",
    analystTake: "ODI batting follows a U-shaped curve. T20 batting is a relentless linear climb, peaking at a 179.97 strike rate in Death Overs.",
    chartConfig: { type: 'line', labels: 'match_phase', dataset: 'strike_rate', label: 'Strike Rate', filterColumn: 'format_name', groupBy: 'batting_role' }
  },
  Q4: {
    title: "Q4. Powerplay Impact on Match Outcome",
    fullQuestion: "Which teams gain the largest proportion of runs from powerplay overs?",
    analystTake: "Narrow gaps between win/loss shares indicate tactical flexibility. Wide gaps highlight reliance on early momentum.",
    chartConfig: { type: 'bar', labels: 'team_name', dataset: ['PP_run_share_wins', 'PP_run_share_losses'], label: 'PP Run Share', filterColumn: 'format_name' }
  },
  Q5: {
    title: "Q5. Wicket-Taking Effectiveness by Phase",
    fullQuestion: "How does wicket-taking effectiveness vary between powerplay and death overs?",
    analystTake: "T20 Death Overs see the highest wicket frequency. In ODI Powerplays, Shami is more lethal per-delivery than Boult.",
    chartConfig: { type: 'horizontalBar', labels: 'bowler_name', dataset: 'balls_per_wicket', label: 'Efficiency', filterColumn: 'format_name', secondaryFilter: 'match_phase' }
  },
  Q6: {
    title: "Q6. Dismissal Type Distribution",
    fullQuestion: "What dismissal types dominate in ODI and T20 World Cups?",
    analystTake: "'Caught' is the constant (60%). Technical dismissals peak early. Run-outs spike to 12% in T20 Death Overs.",
    chartConfig: { type: 'stackedBar', labels: 'match_phase', dataset: 'percentage_share', groupBy: 'dismissal_type', filterColumn: 'format_name' }
  },
  Q7: {
    title: "Q7. Knockout Match Impact Players",
    fullQuestion: "Who are the definitive 'Big Match' players in knockouts?",
    analystTake: "Kohli's 7.73 impact score is a statistical anomaly, making him the King of Knockouts. Starc defines bowling intensity.",
    chartConfig: { type: 'lollipop', labels: 'player_name', dataset: 'total_impact_score', label: 'Impact Score' }
  },
  Q8: {
    title: "Q8. Fielding Contributions by Team",
    fullQuestion: "How do catches and run-outs contribute to fielding dismissals?",
    analystTake: "India leads ODI catch volume. Australia dominates run-outs. England sets the T20 fielding gold standard.",
    chartConfig: { type: 'groupedHorizontalBar', labels: 'team_name', datasets: ['catches', 'run_outs'], label: ['Catches', 'Run Outs'], filterColumn: 'format_name' }
  },
  Q9: {
    title: "Q9. Team Scoring Progression",
    fullQuestion: "How does run rate progression reveal tactical structure?",
    analystTake: "South Africa uses a 'slow-burn' ODI model. England attacks early in T20s. India shows structured, linear acceleration.",
    chartConfig: { type: 'line', labels: 'match_phase', dataset: 'run_rate', label: 'Run Rate', filterColumn: 'format_name', groupBy: 'team_name' }
  },
  Q10: {
    title: "Q10. Venue Scoring Patterns: The Bias Matrix",
    fullQuestion: "How do average 1st and 2nd innings scores compare across venues?",
    analystTake: "Venues above the diagonal line are 'Chasing Paradises', while those below are 'Defensive Fortresses'.",
    chartConfig: { type: 'scatter', labels: 'venue_name', dataset: ['avg_1st_innings_run', 'avg_2nd_innings_run', 'matches_played'], label: 'Scoring Pattern', filterColumn: 'format_name' }
  },
  Q11: {
    title: "Q11. Death-Over Bowling Economy",
    fullQuestion: "Which bowlers are the most economical in the final phase?",
    analystTake: "Jasprit Bumrah is a statistical anomaly (ODI 5.43, T20 5.70). Spinners like Tahir also prove lethal at choking runs.",
    chartConfig: { type: 'horizontalBar', labels: 'bowler_name', dataset: 'death_eco_rate', label: 'Economy Rate', filterColumn: 'format_name' }
  },
  
  // 🌟 Q12: Top-Order Stability (Updated with Swarm Logic)
  Q12: { 
    title: "Q12. Top-Order Stability vs Win Rate", 
    fullQuestion: "How does the percentage of runs scored by the top order (before the 2nd wicket) correlate with winning?", 
    analystTake: "The 'Swarm' trend is undeniable: teams in the 'High Contribution (>60%)' band consistently float to the top with 80-100% win rates (e.g., Australia, England). Reliance on the top order is a primary indicator of match success.", 
    chartConfig: { 
      type: 'scatter', // We will style this as a Swarm Plot in the view
      labels: 'team_name', 
      dataset: ['win_percentage', 'matches_played', 'top_order_contribution_band'], 
      label: 'Success Matrix', 
      filterColumn: 'format_name' 
    } 
  },

  Q13: { 
    title: "Q13. Extras Contribution Analysis", 
    fullQuestion: "Which teams concede the most 'free runs' (extras), and how does this indiscipline impact their total runs conceded?", 
    analystTake: "Extras are hidden defeats. West Indies (T20) gifting ~8-9% of runs as extras highlights discipline issues, whereas New Zealand remains clinically tight. Wides are the most common offender.", 
    chartConfig: { type: 'stackedBar', labels: 'team_name', dataset: ['wide_runs', 'no_ball_runs', 'bye_runs', 'leg_bye_runs'], label: 'Extras Breakdown', filterColumn: 'format_name' } 
  },

  Q14: {
    title: "Q14. Chase Efficiency & Success",
    fullQuestion: "How does run-chase efficiency correlate with overall success?",
    analystTake: "India sets the ODI gold standard (82% win rate). Australia matches this dominance in T20s. New Zealand is efficient but volatile.",
    chartConfig: { type: 'scatter', labels: 'team_name', dataset: ['chase_success_pct', 'rr_efficiency_ratio', 'chases_played'], label: 'Chase Performance', filterColumn: 'format_name' }
  },
  Q15: {
    title: "Q15. Momentum Impact: Run Rate Change After Wickets",
    fullQuestion: "How drastically does a team's scoring rate change immediately following a wicket?",
    analystTake: "Wickets are momentum killers. Nepal and UAE suffer catastrophic T20 crashes (-1.80 RR drop). Pakistan (ODI) is resilient (-0.03).",
    chartConfig: { type: 'dumbbell', labels: 'team_name', dataset: ['avg_rr_before_wicket', 'avg_rr_after_wicket'], label: 'Run Rate Change', filterColumn: 'format_name' }
  }
};

// ----------------------------
// Home page: list questions
// ----------------------------
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

// ----------------------------
// Generic result handler
// ----------------------------
router.get('/query/:id', (req, res) => {
  const queryKey = `Q${req.params.id}`; 
  const sql = queries[queryKey];

  if (!sql) { return res.status(404).send('Query not found'); }

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

    const viewName = `q${req.params.id}_results`;

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