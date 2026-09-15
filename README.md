# Mobile Product A/B Testing & Revenue Analytics

> **End-to-end product analytics case study evaluating whether a mobile A/B test should be rolled out based on conversion, monetization, statistical evidence, and business risk.**

## Executive Summary

This project evaluates a mobile product A/B experiment with **404,770 users** to determine whether Test B creates enough monetization improvement to justify rollout.

The experiment produced a mixed result:

| KPI | Control A | Test B | Interpretation |
|---|---:|---:|---|
| Users | 202,103 | 202,667 | Balanced allocation |
| Conversion | 0.954% | 0.891% | **-6.64% relative** |
| ARPU | 25.41 | 26.75 | **+5.26% observed** |
| ARPPU | 2,664.00 | 3,003.66 | **+12.75% observed** |
| Conversion p-value | — | **0.0350** | Statistically significant |
| ARPU Welch p-value | — | **~0.533** | Not statistically significant |
| Mann–Whitney p-value | — | **~0.063** | Not significant at 5% |

### Business Decision

## **RETEST / ITERATE**

Test B increases observed monetization metrics but reduces conversion. The conversion decline is statistically significant, while the ARPU uplift is not statistically robust.

**Immediate rollout is therefore not justified.**

The recommended next step is a follow-up experiment designed to understand the monetization mechanism while protecting conversion.

---

## Business Problem

A mobile product team is testing a new treatment intended to improve monetization.

The key business question is:

> **Does the treatment improve monetization enough to justify rollout without creating unacceptable damage to conversion?**

Looking at revenue alone would be insufficient. A treatment can generate higher revenue per user while reducing the number of users who convert.

This analysis therefore evaluates:

- Conversion rate
- ARPU
- ARPPU
- Experiment allocation quality
- Statistical significance
- Revenue distribution
- Supporting population linkage
- Business significance
- Final rollout decision

---

## Data Source

The project uses the public **Gamelytics: Mobile Analytics Challenge** dataset from Kaggle.

The source dataset contains:

- `ab_test.csv` — experiment assignment and user-level revenue
- `reg_data.csv` — user registration information
- `auth_data.csv` — user activity/authentication records

The primary experiment analysis is anchored to `ab_test.csv` because it provides the experimental assignment and revenue outcome at the same user-level grain.

Supporting registration and activity tables are used for population/context checks rather than redefining the causal experiment population.

**Source:** [Gamelytics: Mobile Analytics Challenge — Kaggle](https://www.kaggle.com/datasets/debs2x/gamelytics-mobile-analytics-challenge)

---

## Analytical Approach

The project follows a decision-oriented workflow:

**Data → Validation → KPI Analysis → Statistical Testing → Sensitivity Analysis → Business Decision**

### 1. Data Validation

- Schema and grain validation
- Missing-value checks
- Exact duplicate checks
- Experiment population validation
- Supporting-table linkage checks

### 2. Experiment Quality

The experiment contains:

- **404,770 unique experiment users**
- Approximately **49.93% Control / 50.07% Test**
- SRM p-value = **0.3754**

There is no statistically significant evidence of sample-ratio mismatch.

### 3. Business KPIs

Three complementary monetization metrics are used:

**Conversion Rate**

Measures the breadth of monetization:

> Paying users / experiment users

**ARPU**

Measures monetization per experiment user:

> Total revenue / experiment users

**ARPPU**

Measures monetization intensity among paying users:

> Total revenue / paying users

---

## Statistical Methodology

### Conversion

Two-sided hypothesis test at:

**α = 0.05**

Observed result:

- Control: **0.954%**
- Test: **0.891%**
- Relative change: **-6.64%**
- p-value: **0.0350**
- 95% CI for Test − Control: approximately **[-0.122%, -0.004%]**

Because the confidence interval remains below zero, the conversion decline is statistically significant.

### ARPU

Because revenue is highly zero-inflated and right-skewed:

- Welch's t-test is used for the mean comparison.
- Mann–Whitney U is used as a non-parametric sensitivity check.

Results:

- Observed ARPU uplift: **+5.26%**
- Welch p-value: **~0.533**
- Mann–Whitney p-value: **~0.063**

The monetization uplift therefore does not provide strong statistical evidence for an immediate rollout.

---

## Revenue Distribution

Revenue is strongly:

- Zero-inflated
- Right-skewed
- Concentrated among a relatively small number of paying/high-value users

This creates an important analytical risk:

> Mean-based monetization metrics can be influenced by a small number of high-value users.

Therefore, the observed ARPU increase is treated as **directional evidence**, not definitive treatment evidence.

---

## Key Findings

### Experiment Quality

- 404,770 unique experiment users
- Balanced Control/Test allocation
- SRM does not indicate a significant allocation problem
- Primary experiment population remains anchored to the experiment table

### Monetization

Test B shows:

- **+5.26% observed ARPU**
- **+12.75% observed ARPPU**

However, neither result provides sufficiently robust evidence to offset the conversion risk.

### Conversion

Test B produces:

- **-6.64% relative conversion decline**
- **p = 0.0350**
- Statistically significant negative effect

This is the strongest decision-driving signal in the experiment.

---

## Business Interpretation

The experiment creates a clear trade-off:

**Lower conversion + higher observed monetization among users who pay**

This suggests the treatment may be changing monetization intensity or payer behaviour, but the available evidence does not establish that the overall business outcome improves.

The correct analytical response is therefore not to optimize for the most attractive KPI in isolation.

The decision should prioritize:

1. Statistical evidence
2. Direction of risk
3. Magnitude of the effect
4. Revenue robustness
5. Potential downside to the broader user population

---

# Final Decision

## RETEST / ITERATE

**Do not immediately roll out Test B.**

Instead, design a follow-up experiment that:

- Protects conversion
- Isolates the monetization mechanism
- Tests whether the ARPU uplift can be reproduced
- Uses predefined success/failure guardrails
- Separates payer-rate impact from payer-value impact

---

## Power BI Dashboard

The project includes a three-page executive Power BI dashboard.

### Page 1 — Experiment Overview

Focus:

- Total experiment population
- Conversion rate
- ARPU
- ARPPU
- Control vs Test comparison
- Initial business decision

### Page 2 — Revenue & User Behaviour

Focus:

- Conversion comparison
- ARPU comparison
- ARPPU comparison
- KPI lifts
- Revenue distribution
- Population/coverage interpretation

### Page 3 — Experiment Evidence & Decision

Focus:

- Control/Test populations
- Conversion evidence
- SRM
- Revenue statistical evidence
- Business interpretation
- Final experiment decision

Dashboard screenshots are available in:

`/Screenshots/`

---

## SQL Analysis

The SQL layer demonstrates business-oriented analytical querying and population linkage.

Included analyses:

- Experiment setup and validation
- Experiment overview
- Conversion analysis
- Revenue analysis
- Population linkage
- Business questions

See:

`/sql/`

---

## Tools & Skills Demonstrated

### Python
- pandas
- Statistical testing
- Exploratory data analysis
- Distribution analysis
- Experiment analysis

### SQL
- CTEs
- Conditional aggregation
- KPI calculations
- Population linkage
- Business-question analysis

### Power BI
- DAX measures
- KPI cards
- Comparative visuals
- Revenue distribution analysis
- Executive dashboard design
- Decision-oriented storytelling

### Analytics
- A/B testing
- Conversion analysis
- Monetization analytics
- ARPU / ARPPU
- Statistical significance
- Sample-ratio mismatch (SRM)
- Sensitivity analysis
- Business decision-making

---

## Analytical Boundaries

This is an independent portfolio case study based on a public dataset.

The analysis deliberately does **not** claim metrics such as:

- LTV
- CAC
- ROAS
- Churn
- Retention

unless the underlying data supports a defensible definition.

The experiment conclusion is based on the available experiment population, observed revenue, supporting population checks, and statistical evidence.

---

## Portfolio Takeaway

This project demonstrates an important product analytics principle:

> **A statistically significant negative movement in a critical funnel KPI should not be overridden by a non-robust monetization uplift.**

The final recommendation is therefore:

### **RETEST / ITERATE**

The goal of the next experiment should be to determine whether monetization can be improved **without sacrificing conversion**.

---

## Disclaimer

This is an independent portfolio case study using a public dataset. The conclusions represent analysis of the available dataset and are not presented as professional employment experience or production-company results.
