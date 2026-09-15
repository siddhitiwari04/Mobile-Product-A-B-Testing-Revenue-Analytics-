-- ============================================================
-- 01_EXPERIMENT_OVERVIEW.SQL
-- ============================================================
-- WHY:
-- Establish the experiment population and allocation directly
-- in SQL.
--
-- This query answers:
--   How many users are in each experiment group, and what share
--   of the total experiment population does each group represent?
--
-- We keep this query at user level because ab_test is one row
-- per experiment user.
-- ============================================================

SELECT
    testgroup,
    COUNT(DISTINCT user_id) AS users,
    ROUND(
        100.0 * COUNT(DISTINCT user_id)
        / SUM(COUNT(DISTINCT user_id)) OVER (),
        2
    ) AS share_pct
FROM ab_test
GROUP BY testgroup
ORDER BY testgroup;