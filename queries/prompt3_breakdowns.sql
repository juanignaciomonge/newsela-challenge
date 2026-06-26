-- Prompt 3 (breakdowns): answer/accepted rate within buckets of the features
-- that matter most, in long format (dimension, bucket).
--
-- Same feature derivation as the correlations query, scoped to the columns
-- these breakdowns use. Scans body (~36GB) for has_code; materialize the CTE in
-- your own project if running this repeatedly.
with
    current_year as (
        select max(extract(year from creation_date)) as yr
        from `bigquery-public-data.stackoverflow.posts_questions`
    ),

    b as (
        select
            q.answer_count > 0 as got_answer,
            q.accepted_answer_id is not null as got_accepted,
            regexp_contains(q.body, r'<code>') as has_code,
            array_length(split(q.tags, '|')) as num_tags,
            array_length(split(trim(q.title), ' ')) as title_words,
            extract(hour from q.creation_date) as hour_utc,
            u.reputation as owner_reputation,
            q.score,
            q.comment_count
        from `bigquery-public-data.stackoverflow.posts_questions` as q
        cross join current_year
        left join
            `bigquery-public-data.stackoverflow.users` as u on q.owner_user_id = u.id
        where extract(year from q.creation_date) = current_year.yr
    ),

    -- one block per feature; each buckets the rows and counts the two outcomes
    metrics as (
        select
            'has_code' as dimension,
            cast(has_code as string) as bucket,
            count(*) as n,
            avg(cast(got_answer as int64)) as answer_rate,
            avg(cast(got_accepted as int64)) as accepted_rate
        from b
        group by 1, 2

        union all
        select
            'num_tags',
            cast(least(num_tags, 5) as string),  -- "5" = 5 or more
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2

        union all
        select
            'title_words',
            case
                when title_words < 6
                then '1: <6'
                when title_words < 10
                then '2: 6-9'
                when title_words < 14
                then '3: 10-13'
                else '4: 14+'
            end,
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2

        union all
        select
            'owner_reputation',
            case
                when owner_reputation is null
                then '0: unregistered'
                when owner_reputation <= 1
                then '1: new (<=1)'
                when owner_reputation <= 50
                then '2: 1-50'
                when owner_reputation <= 500
                then '3: 51-500'
                when owner_reputation <= 5000
                then '4: 501-5k'
                else '5: 5k+'
            end,
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2

        union all
        select
            'hour_utc',
            lpad(cast(hour_utc as string), 2, '0'),
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2

        union all
        select
            'score',
            case
                when score < 0
                then '0: negative'
                when score = 0
                then '1: zero'
                when score = 1
                then '2: one'
                when score <= 3
                then '3: 2-3'
                else '4: 4+'
            end,
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2

        union all
        select
            'comment_count',
            case
                when comment_count = 0
                then '0'
                when comment_count <= 2
                then '1: 1-2'
                when comment_count <= 5
                then '2: 3-5'
                else '3: 6+'
            end,
            count(*),
            avg(cast(got_answer as int64)),
            avg(cast(got_accepted as int64))
        from b
        group by 1, 2
    )

select
    dimension,
    bucket,
    n,
    round(answer_rate, 3) as answer_rate,
    round(accepted_rate, 3) as accepted_rate
from metrics
order by dimension, bucket
