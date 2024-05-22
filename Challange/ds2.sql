-- Data Scientist 2: Factors - Start Station, Subscriber Type, Start Hour

-- Create the model
CREATE OR REPLACE MODEL austin.model_ds2
OPTIONS (model_type='linear_reg', labels=['durationMinutes']) AS
WITH 
  biketrips AS (
    SELECT
      duration_minutes AS durationMinutes,
      start_station_name AS startStationName,
      EXTRACT(HOUR FROM start_time) AS startHour,
      subscriber_type AS subscriberType,
      EXTRACT(YEAR FROM start_time) AS tripYear
    FROM
      `bigquery-public-data.austin_bikeshare.bikeshare_trips`
    WHERE
      EXTRACT(YEAR FROM start_time) = 2019
  )
SELECT *
FROM biketrips;

-- Evaluate the model
SELECT *
FROM ML.EVALUATE(MODEL `austin.model_ds2`, (
  SELECT
    duration_minutes AS durationMinutes,
    start_station_name AS startStationName,
    EXTRACT(HOUR FROM start_time) AS startHour,
    subscriber_type AS subscriberType,
    EXTRACT(YEAR FROM start_time) AS tripYear
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
));
