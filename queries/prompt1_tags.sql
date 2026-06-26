-- Prompt 1: tags (and tag pairs) by answer volume and approved-answer rate,
-- for the most recent year in the dataset.
-- tags is pipe-delimited, so we split and match exact tokens.
-- Min-volume floors keep the "most/least" rankings off the long tail.
with
    current_year as (
        select max(extract(year from creation_date)) as yr
        from `bigquery-public-data.stackoverflow.posts_questions`
    ),

    questions as (
        select answer_count, accepted_answer_id, split(tags, '|') as tag_array
        from `bigquery-public-data.stackoverflow.posts_questions`
        -- current_year is a single row; the cross join exposes yr to the filter
        cross join current_year
        where tags is not null and extract(year from creation_date) = current_year.yr
    ),

    single_tag as (
        select
            'single' as grain,
            tag as label,
            count(*) as questions,
            -- sum/count instead of avg() so the result is deterministic
            round(sum(answer_count) / count(*), 3) as avg_answers_per_q,
            sum(answer_count) as total_answers,
            round(
                countif(accepted_answer_id is not null) / count(*), 4
            ) as approved_rate
        from questions, unnest(tag_array) as tag
        group by tag
        having questions >= 200
    ),

    -- every unordered tag pair on a question (t1 < t2 dedupes the pair)
    combo as (
        select
            'combo' as grain,
            concat(t1, ' + ', t2) as label,
            count(*) as questions,
            round(sum(answer_count) / count(*), 3) as avg_answers_per_q,
            sum(answer_count) as total_answers,
            round(
                countif(accepted_answer_id is not null) / count(*), 4
            ) as approved_rate
        from questions, unnest(tag_array) as t1, unnest(tag_array) as t2
        where t1 < t2
        group by label
        having questions >= 50
    )

-- re-sort by avg_answers_per_q / approved_rate / total_answers, asc or desc,
-- to read "most" vs "least" on whichever dimension.
select *
from single_tag
union all
select *
from combo
order by approved_rate desc, avg_answers_per_q desc
