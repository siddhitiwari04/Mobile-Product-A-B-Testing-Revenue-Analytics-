-- ============================================================
-- 02_CONVERSION_ANALYSIS.SQL
-- ============================================================
-- WHY:
-- Measure the percentage of experiment users who generated
-- positive revenue in each group.
--
-- Conversion is treated as a binary user outcome:
--   payer     = revenue > 0
--   non-payer = revenue = 0
--
-- The query also shows the absolute difference and relative
-- change from Control A to Test B.
-- ============================================================

WITH group_metrics AS (
    SELECT
        testgroup,
        COUNT(DISTINCT user_id) AS users,
        COUNT(DISTINCT CASE
            WHEN revenue > 0 THEN user_id
        END) AS paying_users
    FROM ab_test
    GROUP BY testgroup
),

conversion AS (
    SELECT
        testgroup,
        users,
        paying_users,
        100.0 * paying_users / users AS conversion_pct
    FROM group_metrics
)

SELECT
    testgroup,
    users,
    paying_users,
    ROUND(conversion_pct, 3) AS conversion_pct,
    ROUND(
        conversion_pct
        - MAX(CASE WHEN testgroup = 'a'
                   THEN conversion_pct END) OVER (),
        3
    ) AS difference_vs_control_pct,
    ROUND(
        100.0 * (
            conversion_pct
            - MAX(CASE WHEN testgroup = 'a'
                       THEN conversion_pct END) OVER ()
        )
        / MAX(CASE WHEN testgroup = 'a'
                   THEN conversion_pct END) OVER (),
        2
    ) AS relative_change_vs_control_pct
FROM conversion
ORDER BY testgroup;