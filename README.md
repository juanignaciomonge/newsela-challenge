# Newsela: Stack Overflow Post Analysis

Take-home solution for the Senior Analytics & Reporting Engineering challenge.
Dataset: [`bigquery-public-data.stackoverflow`](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=stackoverflow). All queries are BigQuery Standard SQL
under [`queries/`](queries/); raw outputs under [`results/`](results/).

> _I used AI assistance to help build this in the best way I could, including the
> Markdown, which isn't my strong suit. That said, I thought through and validated
> every step myself, and I fully understand what each query does and how it arrives
> at its results._

**Definitions used throughout**
- **Approved answer** = question has an accepted answer (`accepted_answer_id is not null`).
- **Approved rate** = share of questions with an accepted answer; **answers/question** = average answers a question receives.
- `tags` is pipe-delimited, so it's split into exact tokens (a `like '%dbt%'` would also match `mdbtable`).
- **"Current year"** is derived dynamically as the latest year in the data (= 2022), not hard-coded.

---

## Prompt 1: Tags with the most/least answers and highest approved rate (current year)

**Query:** [`prompt1_tags.sql`](queries/prompt1_tags.sql)

**Output:** [`results/prompt1_all.csv`](results/prompt1_all.csv)

**Approach.** Filter to current-year questions, `unnest` the tag array, and aggregate
per tag: questions, answers/question, total answers, approved rate. Combinations are
unordered tag pairs from a self-`unnest` (`t1 < t2`). A min-volume floor (≥200 questions
for single tags, ≥50 for pairs) keeps the rankings off the long tail. Only the small
columns are scanned (no `body`).

("Most answers" is reported as answers per question, comparable across volumes. By
*total* answers it's just the popular languages (`python` 190k, `javascript` 131k),
but their approved rates are only ~27-35%, so volume ≠ resolution.)

### Single tags

**Most answers per question:**

| tag | questions | answers/q | approved rate |
|---|--:|--:|--:|
| awk | 1,266 | 2.45 | 66.0% |
| sed | 1,085 | 2.19 | 61.8% |
| function-definition | 249 | 1.89 | 49.8% |
| c-strings | 289 | 1.87 | 45.7% |
| grep | 643 | 1.79 | 51.9% |

**Least answers per question:**

| tag | questions | answers/q | approved rate |
|---|--:|--:|--:|
| facebook-graph-api | 548 | 0.31 | 10.4% |
| ckeditor | 414 | 0.31 | 9.4% |
| wifi | 295 | 0.32 | 7.5% |
| facebook | 962 | 0.32 | 10.2% |
| wsdl | 218 | 0.33 | 11.0% |

**Highest approved rate:**

| tag | questions | answers/q | approved rate |
|---|--:|--:|--:|
| google-query-language | 277 | 1.22 | 89.9% |
| flatten | 248 | 1.29 | 76.6% |
| stringr | 270 | 1.73 | 69.3% |
| jq | 824 | 1.49 | 67.6% |
| awk | 1,266 | 2.45 | 66.0% |

**Lowest approved rate:**

| tag | questions | answers/q | approved rate |
|---|--:|--:|--:|
| wifi | 295 | 0.32 | 7.5% |
| linkedin | 272 | 0.34 | 8.1% |
| openstack | 218 | 0.43 | 8.3% |
| magento2 | 488 | 0.49 | 8.6% |
| facebook-graph-api | 548 | 0.31 | 10.4% |

### Combinations (tag pairs)

**Most answers per question:**

| tag pair | questions | answers/q | approved rate |
|---|--:|--:|--:|
| awk + regex | 53 | 2.92 | 81.1% |
| awk + sed | 375 | 2.92 | 66.7% |
| awk + grep | 170 | 2.70 | 61.8% |
| grep + sed | 141 | 2.62 | 58.2% |
| awk + bash | 514 | 2.59 | 66.0% |

**Least answers per question:**

| tag pair | questions | answers/q | approved rate |
|---|--:|--:|--:|
| ckeditor + ckeditor5 | 93 | 0.23 | 7.5% |
| webpack + webpack-4 | 51 | 0.23 | 3.9% |
| django + elasticsearch | 50 | 0.24 | 10.0% |
| facebook + facebook-graph-api | 275 | 0.24 | 9.8% |
| eclipse + eclipse-plugin | 104 | 0.25 | 15.4% |

**Highest approved rate:**

| tag pair | questions | answers/q | approved rate |
|---|--:|--:|--:|
| arrays + google-query-language | 106 | 1.25 | 97.2% |
| arrays + vlookup | 75 | 1.23 | 96.0% |
| arrays + google-sheets-formula | 145 | 1.28 | 95.9% |
| flatten + google-query-language | 67 | 1.30 | 95.5% |
| flatten + google-sheets-formula | 65 | 1.25 | 95.4% |

**Lowest approved rate:**

| tag pair | questions | answers/q | approved rate |
|---|--:|--:|--:|
| ubuntu + ubuntu-22.04 | 51 | 0.84 | 2.0% |
| appium + automation | 76 | 0.49 | 2.6% |
| entity + java | 63 | 0.65 | 3.2% |
| url + wordpress | 56 | 0.52 | 3.6% |
| sharepoint + sharepoint-2013 | 54 | 0.26 | 3.7% |

---

## Prompt 2: `python`-only vs `dbt`-only, year over year (last 10 years)

**Query:** [`prompt2_python_vs_dbt.sql`](queries/prompt2_python_vs_dbt.sql)

**Output:** [`results/prompt2_yoy.csv`](results/prompt2_yoy.csv)

**Approach.** "Only python/dbt" = the question's sole tag equals `'python'` or `'dbt'`.
Per (tag, year) compute answers/question and approved rate, then attach `lag()`-based
year-over-year deltas, partitioned by tag, over the dynamic 10-year window (2013-2022).

**`python`-only** declines steadily on both metrics:

| year | answers/q | approved rate |
|--:|--:|--:|
| 2013 | 2.31 | 65.2% |
| 2016 | 1.83 | 52.5% |
| 2019 | 1.70 | 48.8% |
| 2022 | 1.26 | 35.4% |

Answers/question fell ~46% and the approved rate from 65% to 35% over the decade.

**`dbt`-only:**

| year | questions | answers/q | approved rate |
|--:|--:|--:|--:|
| 2020 | 31 | 1.39 | 41.9% |
| 2021 | 58 | 1.14 | 25.9% |
| 2022 | 79 | 1.06 | 27.8% |

**Comparison.** `python`-only beats `dbt`-only on both metrics in every overlapping year.
Note that `dbt` as a sole tag only appears from 2020 (≤80 questions/year), so its 10-year
series is short and noisy, which makes the comparison asymmetric. 2022 is also a partial
year, so its rates are slightly understated (less time to accumulate answers/acceptances).

---

## Prompt 3: Non-tag qualities that correlate with answer & approved rate

**Queries:** [`prompt3_correlations.sql`](queries/prompt3_correlations.sql), [`prompt3_breakdowns.sql`](queries/prompt3_breakdowns.sql)

**Outputs:** [`results/prompt3_correlations.csv`](results/prompt3_correlations.csv), [`results/prompt3_breakdowns.csv`](results/prompt3_breakdowns.csv)

**Approach.** Build one feature row per current-year question (1.27M; baseline 61.4%
answered, 30.5% accepted) covering title shape, body (length, code/link presence), tag
count, posting time, asker reputation, and engagement signals. Two views: a point-biserial
correlation to rank features, and bucketed rates to read effect sizes.

**Top correlations (with the accepted-answer outcome):**

| feature | corr w/ answer | corr w/ accepted |
|---|--:|--:|
| has_code | 0.118 | 0.133 |
| score | 0.052 | 0.098 |
| view_count | 0.075 | 0.044 |
| owner_reputation | 0.022 | 0.032 |

**Code block, the strongest controllable factor.** Including a `<code>` block lifts the
answer rate from 49.8% → 64.2% and nearly doubles the approved rate (18.2% → 33.5%).

**Asker reputation drives the approved rate.** New users (rep ≤1) get an accepted answer
only 3% of the time, rising to ~38-40% for established users, because accepting requires
the asker to return, which newcomers rarely do.

| asker reputation | answer rate | approved rate |
|---|--:|--:|
| new (≤1) | 41.0% | 3.0% |
| 1-50 | 65.5% | 34.3% |
| 51-500 | 66.1% | 38.0% |
| 5k+ | 67.9% | 39.8% |

`score` and `view_count` correlate but accrue *after* posting, so they're diagnostic, not
actionable. Smaller effects: a sweet spot of 2 tags and 10-13-word titles; a mild edge for
posting 20:00-02:00 UTC.
