-- =============================================================
-- HR Support Desk Analytics
-- Dataset: Technical Support Dataset (Kaggle)
-- Tool: SQLite
-- Author: [Your Name]
-- =============================================================


-- =============================================================
-- STEP 1: DATA CLEANING
-- =============================================================
-- Why: Raw CSV has duplicate topic labels (different casing),
-- trailing whitespace, and no typed SLA flag columns.
-- We create a clean `tickets` table we can query reliably.

DROP TABLE IF EXISTS tickets;

CREATE TABLE tickets AS
SELECT
    [Ticket ID]                             AS ticket_id,
    TRIM([Status])                          AS status,
    TRIM([Priority])                        AS priority,

    -- Fix: 'Pricing and Licensing' and 'Pricing and licensing'
    -- were two separate values due to inconsistent casing.
    -- Normalize everything to title case.
    CASE
        WHEN LOWER(TRIM([Topic])) = 'pricing and licensing'
        THEN 'Pricing and Licensing'
        ELSE TRIM([Topic])
    END                                     AS topic,

    TRIM([Source])                          AS source,
    TRIM([Agent Group])                     AS agent_group,
    TRIM([Agent Name])                      AS agent_name,
    TRIM([Support Level])                   AS support_level,
    TRIM([Product group])                   AS product_group,
    TRIM([Country])                         AS country,

    -- Trim timestamps to YYYY-MM-DD HH:MM:SS (remove sub-seconds)
    SUBSTR([Created time], 1, 19)           AS created_time,
    SUBSTR([Resolution time], 1, 19)        AS resolution_time,
    SUBSTR([Close time], 1, 19)             AS close_time,
    SUBSTR([First response time], 1, 19)    AS first_response_time,

    TRIM([SLA For Resolution])              AS sla_resolution,
    TRIM([SLA For first response])          AS sla_first_response,

    -- Create binary SLA flags (1 = met, 0 = breached)
    -- Easier to use in AVG() and SUM() calculations
    CASE WHEN TRIM([SLA For Resolution])       = 'Within SLA' THEN 1 ELSE 0 END AS sla_met,
    CASE WHEN TRIM([SLA For first response])   = 'Within SLA' THEN 1 ELSE 0 END AS first_response_sla_met,

    [Agent interactions]                    AS agent_interactions,
    [Survey results]                        AS survey_score,
    [Latitude]                              AS latitude,
    [Longitude]                             AS longitude

FROM raw_tickets;


-- =============================================================
-- STEP 2: ANALYTICAL QUERIES
-- =============================================================


-- ------------------------------------------------------------
-- Q1: SLA Compliance by Topic
-- Business question: Which request categories breach SLA most?
-- Tableau use: Bar chart, color-coded by compliance %
-- ------------------------------------------------------------
SELECT
    topic,
    COUNT(*)                                    AS total_tickets,
    SUM(sla_met)                                AS sla_met_count,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1)  AS sla_compliance_pct
FROM tickets
GROUP BY topic
ORDER BY sla_compliance_pct ASC;


-- ------------------------------------------------------------
-- Q2: Monthly Ticket Volume + SLA Trend
-- Business question: Is SLA compliance improving or declining?
-- Tableau use: Dual-axis line chart (volume + SLA %)
-- ------------------------------------------------------------
SELECT
    SUBSTR(created_time, 1, 7)                          AS month,
    COUNT(*)                                            AS total_tickets,
    SUM(sla_met)                                        AS sla_met,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1)          AS sla_compliance_pct
FROM tickets
WHERE created_time IS NOT NULL
GROUP BY month
ORDER BY month;


-- ------------------------------------------------------------
-- Q3: Agent Performance Scorecard
-- Business question: Which agents handle the most tickets,
-- and how do satisfaction and SLA compliance compare?
-- Tableau use: Table or scatter plot (volume vs. satisfaction)
-- ------------------------------------------------------------
SELECT
    agent_name,
    agent_group,
    COUNT(*)                                            AS total_tickets,
    ROUND(AVG(survey_score), 2)                         AS avg_satisfaction,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1)          AS sla_compliance_pct,
    ROUND(AVG(agent_interactions), 2)                   AS avg_interactions
FROM tickets
GROUP BY agent_name, agent_group
ORDER BY total_tickets DESC;


-- ------------------------------------------------------------
-- Q4: Resolution Time Distribution
-- Business question: How quickly are tickets being resolved?
-- Tableau use: Histogram / bar chart
-- Note: JULIANDAY() converts datetime to days; multiply by 24
-- to get hours.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 4   THEN '0-4 hrs'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 24  THEN '4-24 hrs'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 48  THEN '1-2 days'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 96  THEN '2-4 days'
        ELSE '4+ days'
    END                                                 AS resolution_bucket,
    COUNT(*)                                            AS ticket_count
FROM tickets
WHERE resolution_time IS NOT NULL
  AND created_time IS NOT NULL
GROUP BY resolution_bucket
ORDER BY
    CASE resolution_bucket
        WHEN '0-4 hrs'  THEN 1
        WHEN '4-24 hrs' THEN 2
        WHEN '1-2 days' THEN 3
        WHEN '2-4 days' THEN 4
        ELSE 5
    END;


-- ------------------------------------------------------------
-- Q5: SLA Compliance + Avg Resolution Time by Priority
-- Business question: Are high-priority tickets resolved faster?
-- Tableau use: Grouped bar or highlight table
-- ------------------------------------------------------------
SELECT
    priority,
    COUNT(*)                                            AS total_tickets,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1)          AS sla_compliance_pct,
    ROUND(AVG(
        CASE WHEN resolution_time IS NOT NULL
             THEN (JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24
        END
    ), 1)                                               AS avg_resolution_hrs
FROM tickets
GROUP BY priority
ORDER BY CASE priority WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;
