## The features of this model must incorporate:
#  the starting station name, 
## the hour the trip started, 
## the weekday of the trip,
##  and the address of the start station labelled as location. 
## You must use 2019 Year data only to train this model.

CREATE or REPLACE MODEL austin.austin_location_model
OPTIONS
  (model_type='linear_reg', labels=['duration_minutes']) AS

WITH 
  daynames AS
    (SELECT ['Sun', 'Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat'] AS daysofweek),

  biketrips AS (
  SELECT
    duration_minutes as durationMinutes,
    start_station_name as startStationName,
    EXTRACT(HOUR FROM start_time) AS startHour,
    daysofweek[ORDINAL(EXTRACT(DAYOFWEEK FROM start_time))] AS dayOfWeek,
    EXTRACT(YEAR FROM start_time) AS tripYear,
    stations.address as location
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`, daynames
  WHERE
    tripYear = 2019
  JOIN
    `bigquery-public-data.austin_bikeshare.bikeshare_stations` AS stations
    WHERE start_station_id = stations.station_id
  )

  SELECT *
  FROM biketrips