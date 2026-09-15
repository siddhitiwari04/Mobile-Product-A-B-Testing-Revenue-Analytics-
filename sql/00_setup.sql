-- ============================================================
-- 00_SETUP.SQL — Load the raw source tables
-- ============================================================
-- WHY:
-- The Python analysis starts from the same three raw CSV tables.
-- Here we load them into DuckDB so the SQL layer uses the same
-- source data and preserves each table's original grain.
--
-- ab_test   : one row per experiment user
-- reg_data  : one row per registered user
-- auth_data : multiple activity records per user
-- ============================================================

CREATE OR REPLACE TABLE ab_test AS
SELECT *
FROM read_csv(
    'E:/DA PORTFOLIO/DA-Projects/Product AB Testing & Revenue Analytics/data/raw/ab_test.csv',
    delim=';'
);

CREATE OR REPLACE TABLE reg_data AS
SELECT *
FROM read_csv(
    'E:/DA PORTFOLIO/DA-Projects/Product AB Testing & Revenue Analytics/data/raw/reg_data.csv',
    delim=';'
);

CREATE OR REPLACE TABLE auth_data AS
SELECT *
FROM read_csv(
    'E:/DA PORTFOLIO/DA-Projects/Product AB Testing & Revenue Analytics/data/raw/auth_data.csv',
    delim=';'
);


-- ------------------------------------------------------------
-- Quick validation
-- WHY:
-- Confirm that all three source tables loaded with the expected
-- row counts before writing analytical queries.
-- ------------------------------------------------------------

SELECT 'ab_test' AS table_name, COUNT(*) AS rows FROM ab_test
UNION ALL
SELECT 'reg_data', COUNT(*) FROM reg_data
UNION ALL
SELECT 'auth_data', COUNT(*) FROM auth_data;