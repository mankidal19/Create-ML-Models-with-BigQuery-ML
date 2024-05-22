## Write a query to determine available seasons and games

```
SELECT
  season,
  COUNT(*) as games_per_tournament
  FROM
 `bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games`
 GROUP BY season
 ORDER BY season # default is Ascending (low to high)
```

## Predict the winner of a given NCAA Men's basketball match-up

...using past knowledge of historical games. In machine learning, each column of data that will help us determine the outcome (win or loss for a tournament game) is called a feature.

The column of data that you are trying to predict is called the label. Machine learning models "learn" the association between features to predict the outcome of a label.

Examples of features for your historical dataset could be:

- Season
- Team name
- Opponent team name
- Team seed (ranking)
- Opponent team seed

The label you will be trying to predict for future games will be the game outcome — whether or not a team wins or loses.

### Break the single game record into a record for each team so you can label each row as a "winner" or "loser".

```
# create a row for the winning team
SELECT
  # features
  season, # ex: 2015 season has March 2016 tournament games
  round, # sweet 16
  days_from_epoch, # how old is the game
  game_date,
  day, # Friday

  'win' AS label, # our label

  win_seed AS seed, # ranking
  win_market AS market,
  win_name AS name,
  win_alias AS alias,
  win_school_ncaa AS school_ncaa,
  # win_pts AS points,

  lose_seed AS opponent_seed, # ranking
  lose_market AS opponent_market,
  lose_name AS opponent_name,
  lose_alias AS opponent_alias,
  lose_school_ncaa AS opponent_school_ncaa
  # lose_pts AS opponent_points

FROM `bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games`

UNION ALL

# create a separate row for the losing team
SELECT
# features
  season,
  round,
  days_from_epoch,
  game_date,
  day,

  'loss' AS label, # our label

  lose_seed AS seed, # ranking
  lose_market AS market,
  lose_name AS name,
  lose_alias AS alias,
  lose_school_ncaa AS school_ncaa,
  # lose_pts AS points,

  win_seed AS opponent_seed, # ranking
  win_market AS opponent_market,
  win_name AS opponent_name,
  win_alias AS opponent_alias,
  win_school_ncaa AS opponent_school_ncaa
  # win_pts AS opponent_points

FROM
`bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games`
```

### Creating a machine learning model with BigQuery ML

```
CREATE OR REPLACE MODEL
  `bracketology.ncaa_model`
OPTIONS
  ( model_type='logistic_reg') AS

# create a row for the winning team
SELECT
  # features
  season,

  'win' AS label, # our label

  win_seed AS seed, # ranking
  win_school_ncaa AS school_ncaa,

  lose_seed AS opponent_seed, # ranking
  lose_school_ncaa AS opponent_school_ncaa

FROM `bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games`
WHERE season <= 2017

UNION ALL

# create a separate row for the losing team
SELECT
# features
  season,

  'loss' AS label, # our label
  lose_seed AS seed, # ranking
  lose_school_ncaa AS school_ncaa,

  win_seed AS opponent_seed, # ranking
  win_school_ncaa AS opponent_school_ncaa

FROM
`bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games`

# now we split our dataset with a WHERE clause so we can train on a subset of data and then evaluate and test the model's performance against a reserved subset so the model doesn't memorize or overfit to the training data.

# tournament season information from 1985 - 2017
# here we'll train on 1985 - 2017 and predict for 2018
WHERE season <= 2017
```

### Evaluate model performance

```
SELECT
  *
FROM
  ML.EVALUATE(MODEL   `bracketology.ncaa_model`)
```

The value will be around 69% accurate. While it's better than a coin flip, there is room for improvement.


### Making predictions

```
CREATE OR REPLACE TABLE `bracketology.predictions` AS (

SELECT * FROM ML.PREDICT(MODEL `bracketology.ncaa_model`,

# predicting for 2018 tournament games (2017 season)
(SELECT * FROM `data-to-insights.ncaa.2018_tournament_results`)
)
)
```

### How many did our model get right for the 2018 NCAA tournament?

```
SELECT * FROM `bracketology.predictions`
WHERE predicted_label <> label
```

Out of 134 predictions (67 March tournament games), our model got it wrong 38 times. 70% overall for the 2018 tournament matchup.


### Find biggest upset for the 2017 tournament according to the model. 

We'll look where the model predicts with 80%+ confidence and gets it WRONG.

```
SELECT
  model.label AS predicted_label,
  model.prob AS confidence,

  predictions.label AS correct_label,

  game_date,
  round,

  seed,
  school_ncaa,
  points,

  opponent_seed,
  opponent_school_ncaa,
  opponent_points

FROM `bracketology.predictions` AS predictions,
UNNEST(predicted_label_probs) AS model

WHERE model.prob > .8 AND predicted_label <> predictions.label
```

## Create a new ML dataset with these skillful features

### Create training dataset

Include these features:
- Scoring efficiency over time based on historical play-by-play analysis.
- Possession of the basketball over time.

```
# create training dataset:
# create a row for the winning team
CREATE OR REPLACE TABLE `bracketology.training_new_features` AS
WITH outcomes AS (
SELECT
  # features
  season, # 1994

  'win' AS label, # our label

  win_seed AS seed, # ranking # this time without seed even
  win_school_ncaa AS school_ncaa,

  lose_seed AS opponent_seed, # ranking
  lose_school_ncaa AS opponent_school_ncaa

FROM `bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games` t
WHERE season >= 2014

UNION ALL

# create a separate row for the losing team
SELECT
# features
  season, # 1994

  'loss' AS label, # our label

  lose_seed AS seed, # ranking
  lose_school_ncaa AS school_ncaa,

  win_seed AS opponent_seed, # ranking
  win_school_ncaa AS opponent_school_ncaa

FROM
`bigquery-public-data.ncaa_basketball.mbb_historical_tournament_games` t
WHERE season >= 2014

UNION ALL

# add in 2018 tournament game results not part of the public dataset:
SELECT
  season,
  label,
  seed,
  school_ncaa,
  opponent_seed,
  opponent_school_ncaa
FROM
  `data-to-insights.ncaa.2018_tournament_results`

)

SELECT
o.season,
label,

# our team
  seed,
  school_ncaa,
  # new pace metrics (basketball possession)
  team.pace_rank,
  team.poss_40min,
  team.pace_rating,
  # new efficiency metrics (scoring over time)
  team.efficiency_rank,
  team.pts_100poss,
  team.efficiency_rating,

# opposing team
  opponent_seed,
  opponent_school_ncaa,
  # new pace metrics (basketball possession)
  opp.pace_rank AS opp_pace_rank,
  opp.poss_40min AS opp_poss_40min,
  opp.pace_rating AS opp_pace_rating,
  # new efficiency metrics (scoring over time)
  opp.efficiency_rank AS opp_efficiency_rank,
  opp.pts_100poss AS opp_pts_100poss,
  opp.efficiency_rating AS opp_efficiency_rating,

# a little feature engineering (take the difference in stats)

  # new pace metrics (basketball possession)
  opp.pace_rank - team.pace_rank AS pace_rank_diff,
  opp.poss_40min - team.poss_40min AS pace_stat_diff,
  opp.pace_rating - team.pace_rating AS pace_rating_diff,
  # new efficiency metrics (scoring over time)
  opp.efficiency_rank - team.efficiency_rank AS eff_rank_diff,
  opp.pts_100poss - team.pts_100poss AS eff_stat_diff,
  opp.efficiency_rating - team.efficiency_rating AS eff_rating_diff

FROM outcomes AS o
LEFT JOIN `data-to-insights.ncaa.feature_engineering` AS team
ON o.school_ncaa = team.team AND o.season = team.season
LEFT JOIN `data-to-insights.ncaa.feature_engineering` AS opp
ON o.opponent_school_ncaa = opp.team AND o.season = opp.season

```

### Interpreting selected metrics

#### opp_efficiency_rank
Opponent's Efficiency Rank: out of all the teams, what rank does our opponent have for scoring efficiently over time (points per 100 basketball possessions). Lower is better.

#### opp_pace_rank
Opponent's Pace Rank: out of all teams, what rank does our opponent have for basketball possession (number of possessions in 40 minutes). Lower is better.


As an additional measure to safe-guard your model from "memorizing good teams from the past", exclude the team's name and the seed from this next model and focus only on the metrics.


### Train the new model

```
CREATE OR REPLACE MODEL
  `bracketology.ncaa_model_updated`
OPTIONS
  ( model_type='logistic_reg') AS

SELECT
  # this time, don't train the model on school name or seed
  season,
  label,

  # our pace
  poss_40min,
  pace_rank,
  pace_rating,

  # opponent pace
  opp_poss_40min,
  opp_pace_rank,
  opp_pace_rating,

  # difference in pace
  pace_rank_diff,
  pace_stat_diff,
  pace_rating_diff,


  # our efficiency
  pts_100poss,
  efficiency_rank,
  efficiency_rating,

  # opponent efficiency
  opp_pts_100poss,
  opp_efficiency_rank,
  opp_efficiency_rating,

  # difference in efficiency
  eff_rank_diff,
  eff_stat_diff,
  eff_rating_diff

FROM `bracketology.training_new_features`

# here we'll train on 2014 - 2017 and predict on 2018
WHERE season BETWEEN 2014 AND 2017 # between in SQL is inclusive of end points
```

### Evaluate the new model's performance

```
SELECT
  *
FROM
  ML.EVALUATE(MODEL     `bracketology.ncaa_model_updated`)
```

We've just trained a new model with different features and increased your accuracy to around 75% or a 5% lift from the original model.

###  Inspect what the model learned

```
SELECT
  *
FROM
  ML.WEIGHTS(MODEL     `bracketology.ncaa_model_updated`)
ORDER BY ABS(weight) DESC
```

#### pace_stat_diff
How different the actual stat for (possessions / 40 minutes) was between teams. According to the model, this is the largest driver in choosing the game outcome.

#### eff_stat_diff
How different the actual stat for (net points / 100 possessions) was between teams.

#### eff_rating_diff
How different the normalized rating for scoring efficiency was between teams.


An interesting insight is that the model valued the pace of a team (how well they can control the ball) over how efficiently a team can score.


## Predict with the new model

```
CREATE OR REPLACE TABLE `bracketology.ncaa_2018_predictions` AS

# let's add back our other data columns for context
SELECT
  *
FROM
  ML.PREDICT(MODEL     `bracketology.ncaa_model_updated`, (

SELECT
* # include all columns now (the model has already been trained)
FROM `bracketology.training_new_features`

WHERE season = 2018

))
```

### How many did our new model get right for the 2018 NCAA tournament?

```
SELECT * FROM `bracketology.ncaa_2018_predictions`
WHERE predicted_label <> label
```

As you can see from the number of records returned from the query, the model got 48 matchups wrong (24 games) out of the total number of matchups in the tournament for a 2018 accuracy of 64%. 2018 must have been a wild year, let's look at what upsets happened.


### Find biggest upsets

```
SELECT
CONCAT(school_ncaa, " was predicted to ",IF(predicted_label="loss","lose","win")," ",CAST(ROUND(p.prob,2)*100 AS STRING), "% but ", IF(n.label="loss","lost","won")) AS narrative,
predicted_label, # what the model thought
n.label, # what actually happened
ROUND(p.prob,2) AS probability,
season,

# us
seed,
school_ncaa,
pace_rank,
efficiency_rank,

# them
opponent_seed,
opponent_school_ncaa,
opp_pace_rank,
opp_efficiency_rank

FROM `bracketology.ncaa_2018_predictions` AS n,
UNNEST(predicted_label_probs) AS p
WHERE
  predicted_label <> n.label # model got it wrong
  AND p.prob > .75  # by more than 75% confidence
ORDER BY prob DESC
```


## Compare model performance

```
SELECT
CONCAT(opponent_school_ncaa, " (", opponent_seed, ") was ",CAST(ROUND(ROUND(p.prob,2)*100,2) AS STRING),"% predicted to upset ", school_ncaa, " (", seed, ") and did!") AS narrative,
predicted_label, # what the model thought
n.label, # what actually happened
ROUND(p.prob,2) AS probability,
season,

# us
seed,
school_ncaa,
pace_rank,
efficiency_rank,

# them
opponent_seed,
opponent_school_ncaa,
opp_pace_rank,
opp_efficiency_rank,

(CAST(opponent_seed AS INT64) - CAST(seed AS INT64)) AS seed_diff

FROM `bracketology.ncaa_2018_predictions` AS n,
UNNEST(predicted_label_probs) AS p
WHERE
  predicted_label = 'loss'
  AND predicted_label = n.label # model got it right
  AND p.prob >= .55  # by 55%+ confidence
  AND (CAST(opponent_seed AS INT64) - CAST(seed AS INT64)) > 2 # seed difference magnitude
ORDER BY (CAST(opponent_seed AS INT64) - CAST(seed AS INT64)) DESC
```

## Where were the upsets in March 2018?
```
SELECT
CONCAT(school_ncaa, " was predicted to ",IF(predicted_label="loss","lose","win")," ",CAST(ROUND(p.prob,2)*100 AS STRING), "% but ", IF(n.label="loss","lost","won")) AS narrative,
predicted_label, # what the model thought
n.label, # what actually happened
ROUND(p.prob,2) AS probability,
season,

# us
seed,
school_ncaa,
pace_rank,
efficiency_rank,

# them
opponent_seed,
opponent_school_ncaa,
opp_pace_rank,
opp_efficiency_rank

FROM `bracketology.ncaa_2018_predictions` AS n,
UNNEST(predicted_label_probs) AS p
WHERE
  predicted_label <> n.label # model got it wrong
  AND p.prob > .75  # by more than 75% confidence
ORDER BY prob DESC
```


## Predicting for the 2019 March Madness tournament

### Find first seeds

```
SELECT * FROM `data-to-insights.ncaa.2019_tournament_seeds` WHERE seed = 1
```

### Create a matrix of all possible games

In SQL, an easy way to have a single team play every other team in a table is with a CROSS JOIN.

```
SELECT
  NULL AS label,
  team.school_ncaa AS team_school_ncaa,
  team.seed AS team_seed,
  opp.school_ncaa AS opp_school_ncaa,
  opp.seed AS opp_seed
FROM `data-to-insights.ncaa.2019_tournament_seeds` AS team
CROSS JOIN `data-to-insights.ncaa.2019_tournament_seeds` AS opp
# teams cannot play against themselves :)
WHERE team.school_ncaa <> opp.school_ncaa
```

### Add in 2018 team stats (pace, efficiency)

```
CREATE OR REPLACE TABLE `bracketology.ncaa_2019_tournament` AS

WITH team_seeds_all_possible_games AS (
  SELECT
    NULL AS label,
    team.school_ncaa AS school_ncaa,
    team.seed AS seed,
    opp.school_ncaa AS opponent_school_ncaa,
    opp.seed AS opponent_seed
  FROM `data-to-insights.ncaa.2019_tournament_seeds` AS team
  CROSS JOIN `data-to-insights.ncaa.2019_tournament_seeds` AS opp
  # teams cannot play against themselves :)
  WHERE team.school_ncaa <> opp.school_ncaa
)

, add_in_2018_season_stats AS (
SELECT
  team_seeds_all_possible_games.*,
  # bring in features from the 2018 regular season for each team
  (SELECT AS STRUCT * FROM `data-to-insights.ncaa.feature_engineering` WHERE school_ncaa = team AND season = 2018) AS team,
  (SELECT AS STRUCT * FROM `data-to-insights.ncaa.feature_engineering` WHERE opponent_school_ncaa = team AND season = 2018) AS opp

FROM team_seeds_all_possible_games
)

# Preparing 2019 data for prediction
SELECT

  label,

  2019 AS season, # 2018-2019 tournament season

# our team
  seed,
  school_ncaa,
  # new pace metrics (basketball possession)
  team.pace_rank,
  team.poss_40min,
  team.pace_rating,
  # new efficiency metrics (scoring over time)
  team.efficiency_rank,
  team.pts_100poss,
  team.efficiency_rating,

# opposing team
  opponent_seed,
  opponent_school_ncaa,
  # new pace metrics (basketball possession)
  opp.pace_rank AS opp_pace_rank,
  opp.poss_40min AS opp_poss_40min,
  opp.pace_rating AS opp_pace_rating,
  # new efficiency metrics (scoring over time)
  opp.efficiency_rank AS opp_efficiency_rank,
  opp.pts_100poss AS opp_pts_100poss,
  opp.efficiency_rating AS opp_efficiency_rating,

# a little feature engineering (take the difference in stats)

  # new pace metrics (basketball possession)
  opp.pace_rank - team.pace_rank AS pace_rank_diff,
  opp.poss_40min - team.poss_40min AS pace_stat_diff,
  opp.pace_rating - team.pace_rating AS pace_rating_diff,
  # new efficiency metrics (scoring over time)
  opp.efficiency_rank - team.efficiency_rank AS eff_rank_diff,
  opp.pts_100poss - team.pts_100poss AS eff_stat_diff,
  opp.efficiency_rating - team.efficiency_rating AS eff_rating_diff

FROM add_in_2018_season_stats
```

### Make predictions

```
CREATE OR REPLACE TABLE `bracketology.ncaa_2019_tournament_predictions` AS

SELECT
  *
FROM
  # let's predicted using the newer model
  ML.PREDICT(MODEL     `bracketology.ncaa_model_updated`, (

# let's predict on March 2019 tournament games:
SELECT * FROM `bracketology.ncaa_2019_tournament`
))
```

### Get your predictions

```
SELECT
  p.label AS prediction,
  ROUND(p.prob,3) AS confidence,
  school_ncaa,
  seed,
  opponent_school_ncaa,
  opponent_seed
FROM `bracketology.ncaa_2019_tournament_predictions`,
UNNEST(predicted_label_probs) AS p
WHERE p.prob >= .5
AND school_ncaa = 'Duke'
ORDER BY seed, opponent_seed
```

Insight: Duke (1) is 88.5% favored to beat North Dakota St. (16) on 3/22/19.

Experiment by changing the school_ncaa filter above to predict for the matchups in your bracket. Write down what the model confidence is and enjoy the games!