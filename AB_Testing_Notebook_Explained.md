# A/B Testing Notebook — Explained Line by Line (No Prior Knowledge Needed)

This document walks through **every code cell** in `Complete_A_B_Testing_and_Revenue_Analytics.ipynb` and explains it in plain English. Before diving into the code, here's the 2-minute version of what A/B testing even is.

---

## 0. The Big Picture — What Is A/B Testing?

Imagine you run a mobile game. You have an idea that might make more money — maybe a new pricing screen. You don't want to guess whether it works. So you:

1. Split your users randomly into two groups:
   - **Group A ("Control")** — sees the old version (nothing changes)
   - **Group B ("Test")** — sees the new version
2. Wait and measure what each group does (do they pay? how much?)
3. Compare the two groups' results
4. Ask a critical question: **"Is the difference I see real, or could it just be random luck?"**

That last question is what *statistics* is for. Random groups of people never behave *exactly* identically just by chance — so if Group B makes 2% more money than Group A, that could mean the change works, OR it could mean you got a slightly luckier batch of spenders in Group B by coincidence. Statistical tests calculate how likely it is that "luck alone" could produce a gap this big. If it's very unlikely, we call the result **"statistically significant"** and trust that it's a real effect, not noise.

Key metrics this notebook uses:
- **Conversion rate** — % of users who pay anything at all (spend > $0)
- **ARPU** (Average Revenue Per User) — total money earned ÷ total users (payers AND non-payers)
- **ARPPU** (Average Revenue Per *Paying* User) — total money earned ÷ only the users who paid

With that framing, here's the code.

---

## CELL 1 — Loading the Raw Data

```python
from pathlib import Path
import zipfile
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats
```
This is just gathering tools, like laying out equipment before cooking:
- `pathlib.Path` — lets Python understand file locations (folders/paths) in a clean way.
- `zipfile` — lets Python open `.zip` archives without manually unzipping them first.
- `pandas as pd` — the main data-table library. Think of it as Excel, but controlled by code. We'll use it constantly to load, filter, and summarize data.
- `numpy as np` — a math library for numerical operations (square roots, arrays, log functions, etc.)
- `matplotlib.pyplot as plt` — used to draw charts/graphs.
- `scipy.stats` — a library of statistical formulas and tests (t-tests, z-tests, etc.) — this is the engine behind the "is this real or luck?" question.

```python
DATA_PATH = Path(
    r"E:\DA PORTFOLIO\DA-Projects\Product AB Testing & Revenue Analytics\data\raw\archive.zip"
)
```
This just stores the **file location** of the zipped dataset on the original author's computer (the `r"..."` means "read this text literally, don't treat backslashes specially"). Note: this exact path only exists on the notebook author's PC — if you ran this yourself, you'd need to change it to wherever *your* file lives.

```python
if not DATA_PATH.exists():
    raise FileNotFoundError(f"Dataset not found: {DATA_PATH}")
```
A safety check: "If that file isn't actually there, stop immediately and tell the user clearly, instead of failing later with a confusing error."

```python
with zipfile.ZipFile(DATA_PATH, "r") as z:
    required = {"ab_test.csv", "reg_data.csv", "auth_data.csv"}
    missing = required - set(z.namelist())

    if missing:
        raise FileNotFoundError(f"Missing source file(s): {sorted(missing)}")
```
- Opens the zip file for reading (`"r"`).
- `required` is the set of three CSV files this whole analysis depends on.
- `z.namelist()` lists everything actually inside the zip.
- `required - set(z.namelist())` is set subtraction: "which required files are NOT present?" If anything's missing, stop and say exactly which file is absent — again, failing loudly and early rather than confusingly later.

```python
    ab_test = pd.read_csv(z.open("ab_test.csv"), sep=";")
    reg_data = pd.read_csv(z.open("reg_data.csv"), sep=";")
    auth_data = pd.read_csv(z.open("auth_data.csv"), sep=";")
```
This reads each CSV file **directly out of the zip** (without unzipping it to disk first) into a pandas DataFrame — essentially a spreadsheet-like table living in memory. `sep=";"` tells pandas "columns in this file are separated by semicolons, not commas" (some datasets, especially European ones, use `;` because commas are used as decimal points there).

Result: three tables —
- `ab_test` — one row per user in the experiment, their assigned group, and how much they spent
- `reg_data` — registration info per user
- `auth_data` — login/activity records

```python
print("Source loaded successfully.")
print(f"ab_test   : {len(ab_test):,} rows × {ab_test.shape[1]} columns")
print(f"reg_data  : {len(reg_data):,} rows × {reg_data.shape[1]} columns")
print(f"auth_data : {len(auth_data):,} rows × {auth_data.shape[1]} columns")
```
Just a friendly status report. `len(df)` = number of rows, `df.shape[1]` = number of columns, and `:,` formats the number with comma separators (e.g., `404,770` instead of `404770`) so it's easier to read.

---

## CELL 2 — Data Quality Checks

Before trusting any numbers, you check the data isn't broken (missing values, accidental duplicate rows, etc.) — like checking your scale is zeroed before weighing ingredients.

```python
quality = []

for name, df in {
    "ab_test": ab_test,
    "reg_data": reg_data,
    "auth_data": auth_data
}.items():
    quality.append({
        "table": name,
        "rows": len(df),
        "columns": df.shape[1],
        "null_cells": int(df.isna().sum().sum()),
        "duplicate_rows": int(df.duplicated().sum())
    })
```
This loops through all three tables one at a time and, for each, records:
- `rows` / `columns` — table size
- `null_cells` — `df.isna()` marks every empty/missing cell as `True`. Summing twice (`.sum().sum()`) first counts missing values per column, then adds those up into one grand total across the whole table.
- `duplicate_rows` — `df.duplicated()` flags any row that is an *exact* copy of an earlier row. Summing counts how many such duplicates exist.

Each table's results get appended (added) to the `quality` list as a small dictionary.

```python
quality = pd.DataFrame(quality)
display(quality)
```
Converts that list of dictionaries into a clean table and displays it.

```python
ab_users = ab_test["user_id"].nunique()

print(f"ab_test rows: {len(ab_test):,}")
print(f"Unique experiment users: {ab_users:,}")
print(f"One row per experiment user: {len(ab_test) == ab_users}")
```
`.nunique()` counts **unique** values in the `user_id` column (no double-counting a user who appears twice). This checks: does the number of *rows* equal the number of *unique users*? If yes, each user appears exactly once — which is essential, because if some user appeared twice (e.g., once in each group, or twice in the same group), it would corrupt every calculation downstream.

```python
if len(ab_test) != ab_users:
    raise ValueError("The experiment table is not one row per user.")
```
If that check fails, the whole notebook stops rather than silently producing wrong statistics. This turned out fine here — the check passed.

---

## CELL 3 — Experiment Group Allocation

This checks how many users landed in Group A vs Group B, and whether the split is roughly balanced (ideally close to 50/50).

```python
group_summary = (
    ab_test.groupby("testgroup")["user_id"]
    .nunique()
    .reset_index(name="users")
)
```
- `.groupby("testgroup")` splits the table into two chunks: all rows where `testgroup == "a"`, and all rows where `testgroup == "b"`.
- `["user_id"].nunique()` then counts unique users within each chunk.
- `.reset_index(name="users")` turns the result back into a normal two-column table: `testgroup` and `users` (the count), instead of leaving it in a specialized "grouped" format.

```python
group_summary["share_pct"] = (
    group_summary["users"] / group_summary["users"].sum() * 100
)
```
Adds a new column: what **percentage** of all users each group represents. E.g., if A has 202,000 users and B has 202,770 users, this computes something like 49.93% and 50.07%.

```python
display(group_summary)

print(f"Observed groups: {sorted(ab_test['testgroup'].unique())}")
print("Control group: A")
print("Test group: B")
```
Shows the table, then explicitly lists which group labels actually exist in the data (`.unique()` finds distinct values, `sorted()` puts them in order), and clarifies which is "control" (the baseline/unchanged group) and which is "test" (the group getting the new treatment).

---

## CELL 4 — Core Business KPIs (Conversion, ARPU, ARPPU)

This is where we compute the headline numbers for each group.

```python
kpi = (
    ab_test.assign(payer=ab_test["revenue"] > 0)
    .groupby("testgroup")
    .agg(
        users=("user_id", "nunique"),
        paying_users=("payer", "sum"),
        total_revenue=("revenue", "sum")
    )
    .reset_index()
)
```
Step by step:
- `.assign(payer=ab_test["revenue"] > 0)` creates a brand-new column called `payer`. For every row, it checks "did this user spend more than $0?" — `True` if yes, `False` if no. (In Python, `True` behaves like the number 1 and `False` like 0, which matters for the next step.)
- `.groupby("testgroup")` splits into the A and B groups again.
- `.agg(...)` computes several summary statistics **at once** for each group:
  - `users=("user_id", "nunique")` — count of unique users in that group
  - `paying_users=("payer", "sum")` — since `payer` is True/False (1/0), summing it counts how many users had `payer == True`, i.e., how many people paid anything
  - `total_revenue=("revenue", "sum")` — adds up all money spent by everyone in that group
- `.reset_index()` again flattens the result into a normal table.

```python
kpi["conversion_rate"] = kpi["paying_users"] / kpi["users"]
kpi["arpu"] = kpi["total_revenue"] / kpi["users"]
kpi["arppu"] = kpi["total_revenue"] / kpi["paying_users"]
```
Three new columns, each a simple ratio:
- **Conversion rate** = paying users ÷ all users → "what fraction of people paid anything?"
- **ARPU** = total money ÷ all users → "on average, how much did each user (including non-payers) generate?"
- **ARPPU** = total money ÷ paying users only → "on average, how much did each *paying* user spend?"

```python
display(
    kpi.assign(
        conversion_pct=kpi["conversion_rate"] * 100
    )[
        [
            "testgroup", "users", "paying_users",
            "conversion_pct", "total_revenue", "arpu", "arppu"
        ]
    ].round(2)
)
```
Creates a temporary display-only version of the table: converts conversion rate to a percentage (multiplying by 100), picks out just the columns worth showing, and rounds everything to 2 decimal places for readability. This doesn't change the underlying `kpi` table — it's a one-time formatted view.

```python
control = kpi.loc[kpi["testgroup"] == "a"].iloc[0]
test = kpi.loc[kpi["testgroup"] == "b"].iloc[0]
```
Pulls out group A's row as `control` and group B's row as `test` individually, so we can reference "control's ARPU" or "test's conversion rate" directly in the next step. `.loc[...]` filters rows matching a condition; `.iloc[0]` grabs the single (first/only) matching row as a standalone object.

```python
comparison = pd.DataFrame({
    "metric": ["Conversion Rate", "ARPU", "ARPPU", "Total Revenue"],
    "Control_A": [
        control["conversion_rate"], control["arpu"],
        control["arppu"], control["total_revenue"]
    ],
    "Test_B": [
        test["conversion_rate"], test["arpu"],
        test["arppu"], test["total_revenue"]
    ]
})
```
Builds a brand-new, tidy side-by-side comparison table: one row per metric, with Control A's value and Test B's value next to each other. Much easier to read than having them scattered across separate rows.

```python
comparison["absolute_difference"] = (
    comparison["Test_B"] - comparison["Control_A"]
)
comparison["relative_lift_pct"] = (
    comparison["absolute_difference"] / comparison["Control_A"] * 100
)

display(comparison.round(4))
```
- **Absolute difference** = simple subtraction — how much bigger (or smaller) is B than A, in raw units?
- **Relative lift %** = that difference expressed as a percentage of A's original value — "B is X% higher/lower than A." This is usually the more intuitive number for business decisions (e.g. "6.64% lower conversion" is clearer than "-0.063 percentage points").

The finding at this stage: Test B has *lower conversion* but *higher ARPU and ARPPU* — a classic trade-off (fewer payers, but each pays more) that needs statistical testing before you can trust it's real.

---

## CELL 5 — Revenue Distribution Diagnostic

Before running statistical tests on revenue, we need to check: is revenue "normal" (bell-curve shaped), or weirdly lopsided? This matters because many statistical tests assume roughly bell-curve-shaped data, and using the wrong test on the wrong shape of data gives misleading answers.

```python
revenue_stats = ab_test["revenue"].describe(
    percentiles=[0.50, 0.90, 0.95, 0.99, 0.999]
)

display(revenue_stats.to_frame("revenue"))
```
`.describe()` produces standard summary statistics: count, mean, standard deviation, min, max, and requested percentiles. A **percentile** answers "what value did X% of users fall below?" For example, the 99th percentile revenue tells you the spending level that only the top 1% of users exceed. Checking percentiles like 99% and 99.9% specifically helps reveal **whales** — a tiny number of extremely high-spending users who can single-handedly skew the average.

```python
paying_share = (ab_test["revenue"] > 0).mean()
print(f"Paying-user share: {paying_share:.3%}")
```
`(ab_test["revenue"] > 0)` again creates a True/False column. Taking the `.mean()` of True/False values (True=1, False=0) directly gives the **fraction** of users who paid — this is just conversion rate calculated a different, more compact way. `:.3%` formats it as a percentage with 3 decimal places.

```python
plt.figure(figsize=(9, 4.5))
plt.hist(np.log1p(ab_test["revenue"]), bins=70)
plt.title("User Revenue Distribution — log(1 + revenue)")
plt.xlabel("log(1 + revenue)")
plt.ylabel("Users")
plt.tight_layout()
plt.show()
```
Draws a histogram (a bar chart showing how many users fall into each revenue range).
- `np.log1p(x)` computes `log(1 + x)` instead of raw revenue. Why? Because most users have revenue = 0 (log(0) is undefined/negative infinity, which would break the chart), and a small number of users have huge revenue, which would squash everything else into one tiny sliver of the chart. Taking the log "compresses" huge numbers and makes the shape of the data easier to see visually, while `+1` avoids the log(0) problem.
- `bins=70` splits the range into 70 buckets for the histogram.
- The rest is just labeling and displaying the chart.

**What this reveals:** revenue is "zero-inflated" (a huge pile of users at exactly $0) and "right-skewed" (a long thin tail of big spenders stretching out to the right). This is very different from a bell curve, which is why the notebook later avoids tests that assume normal, symmetric data.

---

## CELL 6 — Supporting Table Linkage

This checks how many of the experiment's users can also be found in the other two tables (registration and login activity), without actually using those tables to change who counts as an experiment user.

```python
registered_ids = set(reg_data["uid"])
active_ids = set(auth_data["uid"])
```
Converts each table's user ID column into a **set** — a collection with no duplicates, optimized for extremely fast "is this ID in here?" lookups.

```python
linkage = pd.DataFrame({
    "population": [
        "Experiment users",
        "Experiment users found in registration data",
        "Experiment users found in activity data"
    ],
    "users": [
        ab_test["user_id"].nunique(),
        ab_test["user_id"].isin(registered_ids).sum(),
        ab_test["user_id"].isin(active_ids).sum()
    ]
})
```
Builds a small table with three rows:
- Row 1: total unique experiment users (baseline count)
- Row 2: `.isin(registered_ids)` checks, for each experiment user, "is this ID also present in the registration table?" — True/False for each — then `.sum()` counts how many were True (i.e., how many matched).
- Row 3: same idea, but checking against the activity/login table instead.

```python
linkage["coverage_pct"] = (
    linkage["users"] / len(ab_test) * 100
)

display(linkage.round(2))
```
Turns each count into a percentage of the total experiment population — "what % of experiment users could we find in this other table?" This matters because if, say, only 40% of experiment users show up in the registration table, you'd know you can't reliably use that table to draw conclusions about the *whole* experiment population — some data would be silently missing/biased.

---

## CELL 7 — Sample Ratio Mismatch Test + Conversion Test

This is the first real *inferential statistics* cell — where we go beyond "what do we observe" to "how confident can we be this is real and not luck." Two separate tests happen here.

### Part A: Sample Ratio Mismatch (SRM) Test

Before trusting *any* result from an A/B test, you must check that the random split itself worked properly. If it's supposed to be 50/50 but you actually got 60/40, something is broken in your experiment setup (e.g., a bug routing more users into one group), and you shouldn't trust the results at all — this is called Sample Ratio Mismatch.

```python
from scipy.stats import chisquare, norm

alpha = 0.05
```
Imports two more statistical tools: `chisquare` (a chi-square test, good for comparing observed counts against expected counts) and `norm` (the normal/bell-curve distribution, used for z-tests).

`alpha = 0.05` sets the **significance threshold**. This is the "how much luck are we willing to tolerate" cutoff. By convention, if there's less than a 5% chance that a result this extreme happened purely by random luck, we call it "statistically significant" — i.e., we believe it's a real effect. This is a widely used (though somewhat arbitrary) standard across science and industry.

```python
observed_users = np.array([len(a) if "a" in ab_test["testgroup"].values else 0,
                           len(b) if "b" in ab_test["testgroup"].values else 0])

srm = chisquare(observed_users)
```
This line has a subtle bug worth flagging: `a` and `b` (the filtered sub-tables for groups A and B) haven't actually been created yet at this point in the notebook — they only get defined a few lines later, in the "Conversion test" section below. In practice this line likely works anyway because Python notebooks let cells reference variables created in *earlier runs*, but if you ran this notebook fresh top-to-bottom in one pass, this exact line would fail with a `NameError`. This is worth fixing if you're rerunning it — you'd want to filter `ab_test` for groups "a" and "b" directly here, before this line.

Conceptually: `chisquare()` compares the actual observed group sizes against what you'd *expect* if the split were perfectly even. It returns a **test statistic** (how far off the counts are) and a **p-value**.

**What's a p-value?** It's the probability of seeing a difference at least this large, purely by random chance, *if there's actually no real difference at all*. A small p-value (e.g., < 0.05) means "this would be a very unlikely coincidence" → suggests a real effect. A large p-value means "this could totally just be random noise" → not enough evidence of a real effect.

```python
print("Sample Ratio Mismatch Test")
print(f"Chi-square statistic: {srm.statistic:.4f}")
print(f"p-value: {srm.pvalue:.4f}")
print(f"Conclusion: {'No significant allocation mismatch' if srm.pvalue >= alpha else 'Potential allocation mismatch'}")
```
Prints the result and a plain-English conclusion: if p-value ≥ 0.05, the group sizes are close enough to 50/50 that we don't suspect a broken randomization. Here it came out fine (p ≈ 0.375), so the split is trustworthy.

### Part B: Conversion Test (Two-Proportion Z-Test)

Now we test whether the *conversion rate* difference between A and B (0.954% vs 0.891%) is statistically real.

```python
a_payers = int((a := ab_test[ab_test["testgroup"] == "a"])["revenue"].gt(0).sum())
b_payers = int((b := ab_test[ab_test["testgroup"] == "b"])["revenue"].gt(0).sum())
```
This is a compact (slightly advanced) piece of Python using the "walrus operator" `:=`, which assigns a variable *and* immediately uses it in the same expression. Unpacked, this line does two things at once:
1. `a = ab_test[ab_test["testgroup"] == "a"]` — creates `a` as the sub-table containing only Group A's rows.
2. `a["revenue"].gt(0).sum()` — counts how many of those rows have revenue greater than 0 (i.e., how many people in A paid).
3. `int(...)` converts the result to a plain integer.

Same logic for group B into `b_payers`. So `a_payers` and `b_payers` are simply "how many people paid" in each group.

```python
a_n, b_n = len(a), len(b)
p_a, p_b = a_payers / a_n, b_payers / b_n
```
`a_n`/`b_n` = total number of users in each group. `p_a`/`p_b` = conversion rate as a decimal (payers ÷ total) for each group — this is what statisticians call a **proportion**.

```python
pooled_p = (a_payers + b_payers) / (a_n + b_n)
se_null = np.sqrt(pooled_p * (1 - pooled_p) * (1/a_n + 1/b_n))
```
This is the mathematical core of the **two-proportion z-test**. The idea: imagine, hypothetically, that A and B actually have the *exact same true* conversion rate (this is called the "null hypothesis" — the assumption of "no real difference"). If that's true, the best estimate of that shared, "pooled" conversion rate is just total payers ÷ total users across both groups combined — that's `pooled_p`.

`se_null` is the **standard error** — essentially, "if the null hypothesis were true, how much natural random wobble would we expect to see between two randomly split groups of this size, just by chance?" It's calculated with a standard statistical formula for proportion differences. Bigger groups → smaller standard error (more precision, less wobble expected).

```python
z = (p_b - p_a) / se_null
p_value = 2 * norm.sf(abs(z))
```
- `z` (the **z-statistic**) measures: "how many standard errors away from zero is the observed gap between B and A?" A z of, say, 2.1 means the observed difference is 2.1 standard errors bigger than you'd expect from pure chance alone — a fairly unusual (but not extreme) result if there's truly no real effect.
- `norm.sf(abs(z))` calculates the probability, under a normal/bell-curve distribution, of getting a z-value *at least this extreme* in one direction (the "survival function," which is `1 - cumulative probability`). Multiplying by 2 accounts for the fact that a difference could be extreme in *either* direction (B higher OR B lower) — this is called a **two-sided test**, since we didn't assume in advance which direction the effect would go.

```python
diff = p_b - p_a
se_diff = np.sqrt(
    p_a * (1 - p_a) / a_n +
    p_b * (1 - p_b) / b_n
)
ci_low = diff - 1.96 * se_diff
ci_high = diff + 1.96 * se_diff
```
This section computes a **95% confidence interval** for the difference between B and A's conversion rates. Unlike the earlier standard error (which assumed no real difference, for the p-value test), this one uses each group's *own actual* observed conversion rate — appropriate for estimating "how big is the real difference, and how uncertain are we?"

A 95% confidence interval means: "if we repeated this exact experiment many times, about 95% of the intervals we'd calculate this way would contain the true difference." The multiplier `1.96` is a standard number that corresponds to 95% confidence for a normal/bell-curve distribution.

If this interval **doesn't include zero** (i.e., both `ci_low` and `ci_high` are negative, or both positive), that's another way of confirming statistical significance — it means "zero difference" is implausible given the data.

```python
print("\nConversion Test")
print(f"Control conversion: {p_a:.3%}")
print(f"Test conversion:    {p_b:.3%}")
print(f"Absolute difference (B - A): {diff:.3%}")
print(f"Relative lift: {diff / p_a:.2%}")
print(f"z-statistic: {z:.4f}")
print(f"p-value: {p_value:.4f}")
print(f"95% CI for B - A: [{ci_low:.3%}, {ci_high:.3%}]")
print(f"Statistically significant at 5%: {p_value < alpha}")
```
Prints everything computed above. The actual result: conversion dropped from 0.954% (A) to 0.891% (B), p = 0.035 (below the 0.05 threshold → statistically significant), and the 95% confidence interval (−0.122% to −0.004%) stays entirely below zero — confirming Test B genuinely converts fewer users, and this isn't just random noise.

---

## CELL 8 — ARPU Test + Sensitivity Analysis

Now we test whether the *revenue* (ARPU) difference is statistically real. Because revenue data is so lopsided (recall Cell 5's histogram — mostly zeros plus a long tail of big spenders), this section uses more careful methods than a basic t-test.

```python
a_rev = a["revenue"].to_numpy()
b_rev = b["revenue"].to_numpy()
```
Pulls the raw revenue numbers out of groups A and B as plain numeric arrays (rather than pandas columns), which is the format scipy's statistical functions expect.

```python
welch = stats.ttest_ind(a_rev, b_rev, equal_var=False)
```
Runs **Welch's t-test**, which compares the *means* (averages) of two groups — this is the standard way to test "is Group B's average revenue really different from Group A's?"

Why `equal_var=False`? A basic ("Student's") t-test assumes both groups have similar spread/variance. Welch's t-test doesn't make that assumption — it's specifically designed for when the two groups might have very different variability, which is exactly the case here (revenue is wildly variable due to those rare big spenders). Welch's version is generally considered the safer default.

```python
mean_diff = b_rev.mean() - a_rev.mean()

var_a = a_rev.var(ddof=1)
var_b = b_rev.var(ddof=1)

se_welch = np.sqrt(var_a / len(a_rev) + var_b / len(b_rev))
```
- `mean_diff` — simple difference in average revenue between groups.
- `.var(ddof=1)` computes **variance** — a measure of how spread-out/variable the data is. `ddof=1` is a technical adjustment ("delta degrees of freedom") that makes the variance estimate unbiased when working from a sample rather than an entire population — this is standard practice and not something to worry about beyond "it's the statistically correct way to do it."
- `se_welch` — the standard error for the *difference in means*, combining both groups' variability, weighted by their sample sizes.

```python
df_welch = (
    (var_a / len(a_rev) + var_b / len(b_rev)) ** 2
    /
    (
        (var_a / len(a_rev)) ** 2 / (len(a_rev) - 1)
        +
        (var_b / len(b_rev)) ** 2 / (len(b_rev) - 1)
    )
)
```
This calculates the **"degrees of freedom"** for Welch's test using a formula called the Welch–Satterthwaite equation. Degrees of freedom is a technical parameter that shapes exactly which statistical curve (t-distribution) is appropriate for this specific comparison — it accounts for the two groups' different sizes and variances. You don't need to memorize the formula; just know it's a standard, necessary ingredient for building an accurate confidence interval when variances differ between groups.

```python
t_critical = stats.t.ppf(1 - alpha/2, df_welch)

arpu_ci_low = mean_diff - t_critical * se_welch
arpu_ci_high = mean_diff + t_critical * se_welch
```
- `stats.t.ppf(...)` looks up the "critical value" from the t-distribution — essentially the analog of that `1.96` number from Cell 7's z-test, but adjusted for this specific sample size/shape (the t-distribution).
- Then builds a 95% confidence interval around the observed mean difference, same logic as before: "we're 95% confident the true average revenue difference between B and A falls somewhere in this range."

```python
mann_whitney = stats.mannwhitneyu(
    a_rev,
    b_rev,
    alternative="two-sided"
)
```
This runs a completely different kind of test: the **Mann–Whitney U test** (also called Wilcoxon rank-sum test). Instead of comparing *averages* (which can be thrown off by a few huge outlier spenders), this test compares the overall *ranking/ordering* of values between the two groups — it asks "if you randomly picked one user from A and one from B, is one group's values tend to rank higher than the other's, more often than chance would predict?" It doesn't care about the exact dollar amounts, just relative ordering, which makes it much more resistant to being skewed by a few whales.

The notebook runs this as a **sensitivity check** — if the t-test and the Mann-Whitney test *agree*, we can be more confident the result is robust. If they *disagree* (as they somewhat did here), it's a signal to be cautious about trusting the mean-based result too strongly.

```python
print("ARPU / Revenue Analysis")
print(f"Control ARPU: {a_rev.mean():.4f}")
print(f"Test ARPU:    {b_rev.mean():.4f}")
print(f"Difference B - A: {mean_diff:.4f}")
print(f"Relative lift: {mean_diff / a_rev.mean():.2%}")
print(f"Welch t-statistic: {welch.statistic:.4f}")
print(f"Welch p-value: {welch.pvalue:.4f}")
print(f"95% CI for B - A: [{arpu_ci_low:.4f}, {arpu_ci_high:.4f}]")
print(f"Mann–Whitney p-value: {mann_whitney.pvalue:.4f}")
```
Prints all results. The actual findings: ARPU looks 5.26% higher in Test B, but Welch's p-value (≈0.533) is way above 0.05 — **not statistically significant**. The Mann-Whitney p-value (≈0.063) is also above 0.05, just barely. Both tests agree: **we cannot confidently say the ARPU increase is real** — it's plausibly just random noise/luck driven by a few high spenders happening to land in Group B.

---

## CELL 9 — Executive Decision (Rule-Based Logic)

This translates the statistical results into a business recommendation, using explicit if/else rules rather than someone's gut feeling — which keeps the conclusion objective and reproducible.

```python
conversion_worse_and_significant = (
    p_value < alpha and p_b < p_a
)

revenue_not_significant = welch.pvalue >= alpha
```
Two True/False checks:
- Is conversion both *statistically significant* (p < 0.05) AND *worse* in B than A?
- Is the revenue/ARPU difference *not statistically significant* (p ≥ 0.05)?

```python
if conversion_worse_and_significant and revenue_not_significant:
    decision = "RETEST / ITERATE"
    rationale = (
        "Test B reduces conversion with statistically significant evidence, "
        "while the observed ARPU increase is not statistically significant."
    )
```
If BOTH of those are true (which is exactly what happened here), the recommendation is "retest/iterate" — because we have solid proof of a real *downside* (fewer payers) but no solid proof of a real *upside* (higher revenue) to offset it.

```python
elif welch.pvalue < alpha and mean_diff > 0 and p_b >= p_a:
    decision = "ROLL OUT"
    rationale = (
        "The test shows statistically significant revenue improvement "
        "without a statistically significant conversion deterioration."
    )
```
Otherwise, if revenue improvement IS statistically significant, positive, AND conversion didn't get significantly worse → recommend full rollout. (Didn't apply here, but shows the logic for a genuinely successful test.)

```python
elif mean_diff < 0 and welch.pvalue < alpha:
    decision = "DO NOT ROLL OUT"
    rationale = (
        "The test produces statistically significant revenue deterioration."
    )
```
If revenue is significantly *worse* → clearly reject the change.

```python
else:
    decision = "RETEST / ITERATE"
    rationale = (
        "The evidence is not sufficiently strong and consistent to support "
        "a confident rollout decision."
    )
```
Catch-all: anything else (e.g., nothing reaches significance either way) → recommend more testing rather than guessing.

```python
print("=" * 70)
print("FINAL EXPERIMENT DECISION")
print("=" * 70)
print(f"\nDecision: {decision}")
print(f"\nRationale:\n{rationale}")
```
Prints a nicely formatted final verdict (`"=" * 70` just repeats the `=` character 70 times to make a visual divider line).

**The actual conclusion reached: "RETEST / ITERATE."** Test B loses paying users for certain, and its apparent revenue gain isn't proven — so it's not safe to roll out as-is.

---

## CELL 10 — Timestamp Coverage Check

A small housekeeping cell, unrelated to the main statistical conclusion — just documenting what time range the supporting tables cover.

```python
reg_dates = pd.to_datetime(reg_data["reg_ts"], unit="s")
auth_dates = pd.to_datetime(auth_data["auth_ts"], unit="s")
```
Converts raw numeric timestamp columns (`reg_ts`, `auth_ts`) into proper calendar dates/times. `unit="s"` tells pandas these numbers represent **Unix timestamps** — the number of seconds since January 1, 1970 — a very common way computers store dates internally.

```python
timestamp_summary = pd.DataFrame({
    "table": ["reg_data", "auth_data"],
    "start": [reg_dates.min(), auth_dates.min()],
    "end": [reg_dates.max(), auth_dates.max()]
})

display(timestamp_summary)
```
Builds a small table showing the earliest and latest dates present in each table — simply to document the data's time coverage for transparency, not used in any statistical test.

---

## Wrapping Up: What Did the Whole Notebook Actually Conclude?

Putting the whole chain of code together, in plain language:

1. **Data loaded cleanly** — no missing values, no duplicates, groups split almost exactly 50/50 (confirmed with a formal test).
2. **Group B (the new variant) converts fewer people into payers** — a 6.64% relative drop, and this is *statistically significant* (very unlikely to be random luck).
3. **Group B appears to earn more per user (ARPU) and per payer (ARPPU)** — but neither of these apparent gains passes the statistical significance bar (two different tests agreed on this), meaning it could easily just be random variation, possibly driven by a few big spenders who happened to land in Group B.
4. **Net verdict:** we have solid proof of a downside (fewer payers) and no solid proof of an upside (more revenue) to justify it. So the responsible business decision is **not** to roll this out yet, but to **retest/iterate** — try to find a version that keeps the potential monetization benefit without losing paying customers.

This is a good example of why you can't just eyeball two numbers and declare a winner — you need the statistical tests to tell you whether an observed difference is trustworthy enough to bet real business decisions on.
