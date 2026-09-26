SELECT CURRENT_USER()      AS my_user,
       CURRENT_ROLE()      AS my_role,
       CURRENT_WAREHOUSE() AS my_warehouse,
       CURRENT_DATABASE()  AS my_database,
       CURRENT_SCHEMA()    AS my_schema,
       CURRENT_REGION()    AS my_region;

SELECT CURRENT_VERSION() AS version;
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS MY_WH
    WAREHOUSE_SIZE      = 'XSMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE MY_WH;

SHOW WAREHOUSES LIKE 'MY_WH';

CREATE SCHEMA IF NOT EXISTS snowflake_learning_db.reconciliation_capstone;

USE SCHEMA snowflake_learning_db.reconciliation_capstone;

SHOW RESOURCE MONITORS;

CREATE OR REPLACE FILE FORMAT csv_ff
  TYPE = 'CSV'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL');

CREATE OR REPLACE STAGE recon_stage
  FILE_FORMAT = csv_ff;

CREATE OR REPLACE TABLE SILVER_GATEWAY (
    txn_id           STRING,
    txn_ts           TIMESTAMP,
    merchant_id      STRING,
    amount           DECIMAL(14,2),
    currency         STRING,
    payment_method   STRING,
    status           STRING,
    _source_file     STRING,
    _ingested_at     TIMESTAMP,
    _row_hash        STRING,
    settled          BOOLEAN,
    settlement_date  DATE
);

CREATE OR REPLACE TABLE SILVER_LEDGER (
    txn_id           STRING,
    txn_ts           TIMESTAMP,
    merchant_id      STRING,
    amount           DECIMAL(14,2),
    currency         STRING,
    payment_method   STRING,
    status           STRING,
    _source_file     STRING,
    _ingested_at     TIMESTAMP,
    _row_hash        STRING,
    settled          BOOLEAN,
    settlement_date  DATE
);

COPY INTO SILVER_GATEWAY
FROM @recon_stage/silver_gateway.csv
FILE_FORMAT = csv_ff;

COPY INTO SILVER_LEDGER
FROM @recon_stage/silver_ledger.csv
FILE_FORMAT = csv_ff;

LIST @recon_stage;


SELECT * from SNOWFLAKE_LEARNING_DB.RECONCILIATION_CAPSTONE.SILVER_GATEWAY;
SELECT * from SNOWFLAKE_LEARNING_DB.RECONCILIATION_CAPSTONE.SILVER_LEDGER;

COPY INTO SILVER_GATEWAY
FROM @recon_stage/silver_gateway.csv
FILE_FORMAT = csv_ff;

COPY INTO SILVER_LEDGER
FROM @recon_stage/silver_ledger.csv
FILE_FORMAT = csv_ff;


SELECT COALESCE(g.settlement_date, l.settlement_date) AS settle_day,
       COUNT_IF(l.txn_id IS NULL) AS gateway_only,
       COUNT_IF(g.txn_id IS NULL) AS ledger_only,
       COUNT_IF(g.txn_id IS NOT NULL AND g.amount IS NULL) AS amount_missing,
       COUNT_IF(ABS(g.amount - l.amount) > 0.05) AS amount_mismatch,
       ROUND(SUM(CASE WHEN g.txn_id IS NOT NULL AND g.amount IS NULL THEN 0
                 ELSE ABS(COALESCE(g.amount,0) - COALESCE(l.amount,0)) END),2) AS gross_break,
       ROUND(SUM(CASE WHEN g.txn_id IS NOT NULL AND g.amount IS NULL THEN 0
                 ELSE COALESCE(g.amount,0) - COALESCE(l.amount,0) END),2) AS net_break
FROM SILVER_GATEWAY g FULL OUTER JOIN SILVER_LEDGER l ON l.txn_id = g.txn_id
GROUP BY settle_day ORDER BY gross_break DESC;


SELECT
  SUM(gateway_only)    AS total_gateway_only,     -- expect 208
  SUM(ledger_only)     AS total_ledger_only,       -- expect 193
  SUM(amount_missing)  AS total_amount_missing     -- expect 350
FROM (
  SELECT COALESCE(g.settlement_date, l.settlement_date) AS settle_day,
         COUNT_IF(l.txn_id IS NULL) AS gateway_only,
         COUNT_IF(g.txn_id IS NULL) AS ledger_only,
         COUNT_IF(g.txn_id IS NOT NULL AND g.amount IS NULL) AS amount_missing
  FROM SILVER_GATEWAY g FULL OUTER JOIN SILVER_LEDGER l ON l.txn_id = g.txn_id
  GROUP BY settle_day
);