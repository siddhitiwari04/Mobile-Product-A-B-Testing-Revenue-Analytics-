-- ============================================================
-- 05_BUSINESS_QUESTIONS.SQL
-- ============================================================
-- WHY:
-- Combine experiment outcomes with user-level activity coverage.
--
-- auth_data contains multiple rows per user, so it is first
-- reduced to one row per user. This prevents activity events
-- from multiplying experiment users during the join.
--
-- The result helps answer:
--   Are the experiment groups similarly represented in the
--   supporting activity data while their business outcomes differ?
-- ============================================================

WITH activity_users AS (
    SELECT DISTINCT
        uid AS user_id
    FROM auth_data
),

experiment AS (
    SELECT
        testgroup,
        user_id,
        revenue,
        CASE
            WHEN revenue > 0 THEN 1
            ELSE 0
        END AS payer
    FROM ab_test
),

group_summary AS (
    SELECT
        e.testgroup,
        COUNT(*) AS users,
        SUM(e.payer) AS paying_users,
        SUM(e.revenue) AS total_revenue,
        SUM(
            CASE
                WHEN a.user_id IS NOT NULL THEN 1
                ELSE 0
            END
        ) AS users_with_activity
    FROM experiment e
    LEFT JOIN activity_users a
        ON e.user_id = a.user_id
    GROUP BY e.testgroup
)

SELECT
    testgroup,
    users,
    paying_users,

    ROUND(
        100.0 * paying_users / users,
        3
    ) AS conversion_pct,

    ROUND(
        total_revenue / users,
        2
    ) AS arpu,

    ROUND(
        100.0 * users_with_activity / users,
        2
    ) AS activity_coverage_pct

FROM group_summary
ORDER BY testgroup;