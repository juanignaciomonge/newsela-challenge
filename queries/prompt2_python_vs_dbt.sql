-- Prompt 2: python-only vs dbt-only questions, year over year, last 10 years.
-- "only" = the question's single tag is exactly 'python' or 'dbt'.
-- ratio = answers per question; approved_rate = share with an accepted answer.
-- Note: dbt-only only appears from 2020, so its series is short (see README).
with
    bounds as (
        select
            max(extract(year from creation_date)) as max_year,
            max(extract(year from creation_date)) - 9 as min_year
        from `bigquery-public-data.stackoverflow.posts_questions`
    ),

    yearly as (
        select
            tags as tag,
            extract(year from creation_date) as yr,
            count(*) as questions,
            sum(answer_count) as total_answers,
            safe_divide(sum(answer_count), count(*)) as answers_per_question,
            safe_divide(
                countif(accepted_answer_id is not null), count(*)
            ) as approved_rate
        from `bigquery-public-data.stackoverflow.posts_questions`
        cross join bounds
        where
            tags in ('python', 'dbt')
            and extract(year from creation_date)
            between bounds.min_year and bounds.max_year
        group by tag, yr
    )

select
    tag,
    yr,
    questions,
    round(answers_per_question, 4) as answers_per_question,
    round(approved_rate, 4) as approved_rate,
    -- change vs the same tag's previous year; null in each tag's first year (no prior)
    round(answers_per_question - lag(answers_per_question) over w, 4) as apq_yoy_delta,
    round(approved_rate - lag(approved_rate) over w, 4) as approved_yoy_delta
from yearly
window w as (partition by tag order by yr)
order by tag, yr
