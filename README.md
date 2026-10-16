# Support Desk Analytics

**Where do support requests get stuck, and is the team getting faster or slower?**

At TriNet Zenefits I handled about 25 benefits cases a day against a 48-hour SLA, so I know how quickly a queue goes from fine to behind. Here I took a public dataset of 2,330 support tickets from 2023 and looked at it the way an HR or people-ops team would: SLA compliance, resolution time and whether priority actually changes anything.

**Tools:** SQL (SQLite) · Python (pandas) · Tableau Public &nbsp;|&nbsp; **Data:** public Kaggle tech-support dataset, not employer data

![Support desk dashboard](dashboard.png)

---

## What I found

- **SLA compliance fell from 76% to 60% over the year.** Workload seems to be outpacing the team.
- **Training requests were the hardest to close on time,** with only 57.6% within SLA.
- **High-priority tickets weren't resolved any faster than low-priority ones,** so the priority flag isn't changing how work gets picked up.
- **There's a long tail:** 586 tickets took more than 4 days, while 839 (36%) were closed within 4–24 hours.
- **Average resolution time varies a lot between agents.** The fastest agent's average (26.2 hours) is a realistic internal benchmark.

## What I'd look at next

1. **Find out why priority doesn't speed things up.** Is it the routing, or is the label not used consistently?
2. **Review the training-request queue first,** since it misses SLA most often.
3. **Track the 4+ day tickets separately**, so they don't hide inside a monthly average.

## The questions

- Which request types miss SLA most?
- Is SLA compliance getting better or worse over time?
- How long do tickets take to resolve?
- Do high-priority tickets get resolved faster?
- How does performance differ between agents?

---

## Data Cleaning Steps

The raw dataset required the following cleaning before analysis:

1. **Duplicate topic labels** — 'Pricing and licensing' and 'Pricing and Licensing' were two separate values due to inconsistent casing. Normalized to title case.
2. **Whitespace** — All text columns trimmed using TRIM()
3. **Date formatting** — Timestamps trimmed to YYYY-MM-DD HH:MM:SS format using SUBSTR()
4. **SLA binary flags** — Created sla_met (1/0) column from text values for easier aggregation in SQL and Tableau
5. **Null handling** — 418 tickets have no resolution time (open/in-progress) — excluded from resolution time calculations

---

## SQL Queries

Five analytical queries power the dashboard:

### Q1: SLA Compliance by Topic
```sql
SELECT
    topic,
    COUNT(*) AS total_tickets,
    SUM(sla_met) AS sla_met_count,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1) AS sla_compliance_pct
FROM tickets
GROUP BY topic
ORDER BY sla_compliance_pct ASC;
```

### Q2: Monthly SLA Trend
```sql
SELECT
    SUBSTR(created_time, 1, 7) AS month,
    COUNT(*) AS total_tickets,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1) AS sla_compliance_pct
FROM tickets
WHERE created_time IS NOT NULL
GROUP BY month
ORDER BY month;
```

### Q3: Agent Performance
```sql
SELECT
    agent_name,
    COUNT(*) AS total_tickets,
    ROUND(AVG(survey_score), 2) AS avg_satisfaction,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1) AS sla_compliance_pct,
    ROUND(AVG(agent_interactions), 2) AS avg_interactions
FROM tickets
GROUP BY agent_name
ORDER BY total_tickets DESC;
```

### Q4: Resolution Time Distribution
```sql
SELECT
    CASE
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 4 THEN '0-4 hrs'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 24 THEN '4-24 hrs'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 48 THEN '1-2 days'
        WHEN ROUND((JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24, 1) <= 96 THEN '2-4 days'
        ELSE '4+ days'
    END AS resolution_bucket,
    COUNT(*) AS ticket_count
FROM tickets
WHERE resolution_time IS NOT NULL
GROUP BY resolution_bucket;
```

### Q5: SLA Compliance by Priority
```sql
SELECT
    priority,
    COUNT(*) AS total_tickets,
    ROUND(SUM(sla_met) * 100.0 / COUNT(*), 1) AS sla_compliance_pct,
    ROUND(AVG(
        CASE WHEN resolution_time IS NOT NULL
             THEN (JULIANDAY(resolution_time) - JULIANDAY(created_time)) * 24
        END
    ), 1) AS avg_resolution_hrs
FROM tickets
GROUP BY priority
ORDER BY CASE priority WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;
```

---

## Dataset

- **Source:** [Technical Support Dataset — Kaggle](https://www.kaggle.com/datasets/suvroo/technical-support-dataset)
- **Size:** 2,330 tickets
- **Period:** January 2023 — December 2023
- **Fields:** Ticket ID, Status, Priority, Topic, Agent, Created Time, Resolution Time, SLA Status, Survey Score, Country

---

## How to Run

```bash
# Clone the repo
git clone https://github.com/vigneshwari2408/hr-support-desk-analytics.git
cd hr-support-desk-analytics

# Install dependencies
pip install pandas jupyter

# Explore the cleaning steps
jupyter notebook data_cleaning.ipynb

# Run the SQL queries against tickets_clean.csv using SQLite or DB Browser for SQLite,
# or open analysis.sql directly
```

---

---

Made by **Vigneshwari Nalla (Vee)** · MSc Data Analytics for Business, KEDGE Business School
[website](https://vigneshwari2408.github.io/vigneshwari-portfolio/) · [linkedin](https://www.linkedin.com/in/vigna24/) · [all projects](https://github.com/vigneshwari2408)
