-- Identify busiest station

WITH trip_counts AS (
  SELECT
    start_station_name,
    COUNT(*) AS trip_count
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
  GROUP BY
    start_station_name
)
SELECT
  start_station_name
FROM
  trip_counts
ORDER BY
  trip_count DESC
LIMIT 1;


-- Predict Average Trip Duration

SELECT
  AVG(predicted_durationMinutes) AS avg_predicted_duration
FROM
  ML.PREDICT(MODEL `austin.model_ds2`, (
    SELECT
     start_station_name AS startStationName,
      EXTRACT(HOUR FROM start_time) AS startHour,
    subscriber_type AS subscriberType,
    EXTRACT(YEAR FROM start_time) AS tripYear
    FROM
      `bigquery-public-data.austin_bikeshare.bikeshare_trips`
    WHERE
      start_station_name = '21st & Speedway @PCL'
      AND subscriber_type = 'Single Trip'
      AND EXTRACT(YEAR FROM start_time) = 2019
  ));
