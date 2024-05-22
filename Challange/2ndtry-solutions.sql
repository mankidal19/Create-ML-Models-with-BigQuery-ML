student_04_6872a09d027f@cloudshell:~ (qwiklabs-gcp-03-461ed2f81435)$ bq --location=US mk --dataset bq_dataset
BigQuery error in mk operation: Dataset 'qwiklabs-gcp-03-461ed2f81435:bq_dataset' already exists.
student_04_6872a09d027f@cloudshell:~ (qwiklabs-gcp-03-461ed2f81435)$ bq query --use_legacy_sql=false "
CREATE OR REPLACE MODEL bqml_dataset.predicts_visitor_model
OPTIONS(model_type='logistic_reg') AS
SELECT
  IF(totals.transactions IS NULL, 0, 1) AS label,
  IFNULL(device.operatingSystem, '') AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.country, '') AS country,
  IFNULL(totals.pageviews, 0) AS pageviews
FROM
  \`bigquery-public-data.google_analytics_sample.ga_sessions_*\`
WHERE
  _TABLE_SUFFIX BETWEEN '20160801' AND '20170631'
  LIMIT 100000;
"
Waiting on bqjob_r52b9921164f9577a_0000018fa03fd37e_1 ... (89s) Current status: DONE   
Created qwiklabs-gcp-03-461ed2f81435.bqml_dataset.predicts_visitor_model

student_04_6872a09d027f@cloudshell:~ (qwiklabs-gcp-03-461ed2f81435)$ bq query --use_legacy_sql=false \
"
#standardSQL
SELECT
  *
FROM
  ml.EVALUATE(MODEL \`bqml_dataset.predicts_visitor_model\`, (
SELECT
  IF(totals.transactions IS NULL, 0, 1) AS label,
  IFNULL(device.operatingSystem, '') AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.country, '') AS country,
  IFNULL(totals.pageviews, 0) AS pageviews
FROM
  \`bigquery-public-data.google_analytics_sample.ga_sessions_*\`
WHERE
  _TABLE_SUFFIX BETWEEN '20170701' AND '20170801'));
"
Waiting on bqjob_r4fde51e8787ceed4_0000018fa041d479_1 ... (1s) Current status: DONE   
+--------------------+---------------------+--------------------+---------------------+----------------------+--------------------+
|     precision      |       recall        |      accuracy      |      f1_score       |       log_loss       |      roc_auc       |
+--------------------+---------------------+--------------------+---------------------+----------------------+--------------------+
| 0.4251497005988024 | 0.06610800744878957 | 0.9852221385542169 | 0.11442385173247381 | 0.048438653645922404 | 0.9827152847152847 |
+--------------------+---------------------+--------------------+---------------------+----------------------+--------------------+
student_04_6872a09d027f@cloudshell:~ (qwiklabs-gcp-03-461ed2f81435)$ bq query --use_legacy_sql=false \
"
#standardSQL
SELECT
  country,
  SUM(predicted_label) as total_predicted_purchases
FROM
  ml.PREDICT(MODEL \`bqml_dataset.predicts_visitor_model\`, (
SELECT
  IFNULL(device.operatingSystem, '') AS os,
  device.isMobile AS is_mobile,
  IFNULL(totals.pageviews, 0) AS pageviews,
  IFNULL(geoNetwork.country, '') AS country
FROM
  \`bigquery-public-data.google_analytics_sample.ga_sessions_*\`
WHERE
  _TABLE_SUFFIX BETWEEN '20170701' AND '20170801'))
GROUP BY country
ORDER BY total_predicted_purchases DESC
LIMIT 10;
"
Waiting on bqjob_r3f0f8521afd50aba_0000018fa0425355_1 ... (0s) Current status: DONE   
+----------------+---------------------------+
|    country     | total_predicted_purchases |
+----------------+---------------------------+
| United States  |                       140 |
| Taiwan         |                         6 |
| Canada         |                         4 |
| India          |                         2 |
| Turkey         |                         2 |
| Japan          |                         2 |
| Brazil         |                         1 |
| Serbia         |                         1 |
| United Kingdom |                         1 |
| Australia      |                         1 |
+----------------+---------------------------+
student_04_6872a09d027f@cloudshell:~ (qwiklabs-gcp-03-461ed2f81435)$ bq query --use_legacy_sql=false \
"
#standardSQL
SELECT
  fullVisitorId,
  SUM(predicted_label) as total_predicted_purchases
FROM
  ml.PREDICT(MODEL \`bqml_dataset.predicts_visitor_model\`, (
SELECT
  IFNULL(device.operatingSystem, '') AS os,
  device.isMobile AS is_mobile,
  IFNULL(totals.pageviews, 0) AS pageviews,
  IFNULL(geoNetwork.country, '') AS country,
  fullVisitorId
FROM
  \`bigquery-public-data.google_analytics_sample.ga_sessions_*\`
WHERE
  _TABLE_SUFFIX BETWEEN '20170701' AND '20170801'))
GROUP BY fullVisitorId
ORDER BY total_predicted_purchases DESC
LIMIT 10;
"
Waiting on bqjob_r55adb59e23a388d2_0000018fa042b7fd_1 ... (0s) Current status: DONE   
+---------------------+---------------------------+
|    fullVisitorId    | total_predicted_purchases |
+---------------------+---------------------------+
| 9417857471295131045 |                         3 |
| 1280993661204347450 |                         2 |
| 057693500927581077  |                         2 |
| 2969418676126258798 |                         2 |
| 806992249032686650  |                         2 |
| 8388931032955052746 |                         2 |
| 7420300501523012460 |                         2 |
| 112288330928895942  |                         2 |
| 0376394056092189113 |                         2 |
| 1902325935306588509 |                         1 |
+---------------------+---------------------------+