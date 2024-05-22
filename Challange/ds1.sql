-- Create the model
CREATE OR REPLACE MODEL austin.model_ds1
OPTIONS (model_type='linear_reg', labels=['durationMinutes']) AS

WITH 
  daynames AS (
    SELECT ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] AS daysofweek
  ),
  biketrips AS (
    SELECT
      duration_minutes AS durationMinutes,
      start_station_name AS startStationName,
      EXTRACT(HOUR FROM start_time) AS startHour,
      daynames.daysofweek[ORDINAL(EXTRACT(DAYOFWEEK FROM start_time))] AS dayOfWeek,
      EXTRACT(YEAR FROM start_time) AS tripYear,
      stations.address AS location
    FROM
      `bigquery-public-data.austin_bikeshare.bikeshare_trips` AS trips
    JOIN
      `bigquery-public-data.austin_bikeshare.bikeshare_stations` AS stations
    ON
      trips.start_station_id = stations.station_id,
      daynames
    WHERE
      EXTRACT(YEAR FROM start_time) = 2019
  )
SELECT *
FROM biketrips;

-- Evaluate the model
SELECT *
FROM ML.EVALUATE(MODEL `austin.model_ds1`, (
  WITH 
    daynames AS (
      SELECT ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] AS daysofweek
    )
  SELECT
    duration_minutes AS durationMinutes,
    start_station_name AS startStationName,
    EXTRACT(HOUR FROM start_time) AS startHour,
    daynames.daysofweek[ORDINAL(EXTRACT(DAYOFWEEK FROM start_time))] AS dayOfWeek,
    EXTRACT(YEAR FROM start_time) AS tripYear,
    stations.address AS location
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips` AS trips
  JOIN
    `bigquery-public-data.austin_bikeshare.bikeshare_stations` AS stations
  ON
    trips.start_station_id = stations.station_id,
    daynames
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
));
