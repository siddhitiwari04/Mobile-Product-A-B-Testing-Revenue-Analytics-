-- ============================================================
-- 03_REVENUE_ANALYSIS.SQL
-- ============================================================
-- WHY:
-- Compare monetization between Control A and Test B.
--
-- ARPU  = total revenue / all experiment users
-- ARPPU = total revenue / paying users
--
-- Looking at both metrics helps separate:
--   1. revenue generated across the full population, and
--   2. revenue intensity among users who actually pay.
-- ============================================================

WITH group_metrics AS (
    SELECT
        testgroup,
        COUNT(DISTINCT user_id) AS users,
        COUNT(DISTINCT CASE
            WHEN revenue > 0 THEN user_id
        END) AS paying_users,
        SUM(revenue) AS total_revenue
    FROM ab_test
    GROUP BY testgroup
),

monetization AS (
    SELECT
        testgroup,
        users,
        paying_users,
        total_revenue,
        total_revenue / users AS arpu,
        total_revenue / NULLIF(paying_users, 0) AS arppu
    FROM group_metrics
)

SELECT
    testgroup,
    users,
    paying_users,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(arpu, 2) AS arpu,
    ROUND(arppu, 2) AS arppu,

    ROUND(
        100.0 * (
            arpu
            - MAX(CASE
                WHEN testgroup = 'a' THEN arpu
              END) OVER ()
        )
        / MAX(CASE
            WHEN testgroup = 'a' THEN arpu
          END) OVER (),
        2
    ) AS arpu_change_vs_control_pct,

    ROUND(
        100.0 * (
            arppu
            - MAX(CASE
                WHEN testgroup = 'a' THEN arppu
              END) OVER ()
        )
        / MAX(CASE
            WHEN testgroup = 'a' THEN arppu
          END) OVER (),
        2
    ) AS arppu_change_vs_control_pct

FROM monetization
ORDER BY testgroup;