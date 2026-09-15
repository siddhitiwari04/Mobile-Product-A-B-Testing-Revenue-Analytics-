-- ============================================================
-- 04_POPULATION_LINKAGE.SQL
-- ============================================================
-- WHY:
-- Measure how much of the experiment population can be linked
-- to the supporting registration and activity tables.
--
-- IMPORTANT:
-- auth_data contains multiple rows per user.
-- We therefore use EXISTS rather than joining raw activity rows
-- to the experiment population. This preserves one row per
-- experiment user and avoids accidental row multiplication.
-- ============================================================

SELECT
    COUNT(*) AS experiment_users,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM reg_data r
            WHERE r.uid = a.user_id
        )
    ) AS linked_to_registration,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM auth_data h
            WHERE h.uid = a.user_id
        )
    ) AS linked_to_activity,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM reg_data r
                WHERE r.uid = a.user_id
            )
        ) / COUNT(*),
        2
    ) AS registration_coverage_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM auth_data h
                WHERE h.uid = a.user_id
            )
        ) / COUNT(*),
        2
    ) AS activity_coverage_pct

FROM ab_test a;