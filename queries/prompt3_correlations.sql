-- Prompt 3 (correlations): point-biserial correlation of each non-tag quality
-- with the two outcomes (got_answer, got_accepted). Ranking matters more than
-- magnitude (n ~ 1.3M, so every coefficient is significant).
--
-- The `features` CTE is the per-question feature set; it scans body (~36GB,
-- unpartitioned table). If you run this and the breakdowns repeatedly, wrap the
-- CTE in a `create table ... as` in your own project and select from that, so
-- body is scanned only once.
with
    current_year as (
        select max(extract(year from creation_date)) as yr
        from `bigquery-public-data.stackoverflow.posts_questions`
    ),

    features as (
        select
            q.answer_count > 0 as got_answer,
            q.accepted_answer_id is not null as got_accepted,
            length(q.title) as title_len,
            array_length(split(trim(q.title), ' ')) as title_words,
            regexp_contains(q.title, r'\?') as title_has_qmark,
            length(q.body) as body_len,
            regexp_contains(q.body, r'<code>') as has_code,
            regexp_contains(q.body, r'<(img|a)\b') as has_img_or_link,
            array_length(split(q.tags, '|')) as num_tags,
            u.reputation as owner_reputation,
            date_diff(
                date(q.creation_date), date(u.creation_date), day
            ) as owner_age_days,
            q.owner_user_id is not null as has_registered_owner,
            q.score,
            q.comment_count,
            q.view_count,
            q.favorite_count
        from `bigquery-public-data.stackoverflow.posts_questions` as q
        cross join current_year
        left join
            `bigquery-public-data.stackoverflow.users` as u on q.owner_user_id = u.id
        where extract(year from q.creation_date) = current_year.yr
    ),

    -- cast every boolean to 0/1 so corr() can take it (point-biserial correlation)
    feats as (
        select
            cast(got_answer as int64) as ans,
            cast(got_accepted as int64) as acc,
            cast(has_code as int64) as has_code,
            cast(has_img_or_link as int64) as has_img_or_link,
            cast(title_has_qmark as int64) as title_has_qmark,
            cast(has_registered_owner as int64) as has_registered_owner,
            title_len,
            title_words,
            body_len,
            num_tags,
            owner_reputation,
            owner_age_days,
            score,
            view_count,
            comment_count,
            favorite_count
        from features
    ),

    -- one wide row, two correlations per feature: __a = vs got_answer, __c = vs
    -- got_accepted
    corrs as (
        select
            corr(has_code, ans) as has_code__a,
            corr(has_code, acc) as has_code__c,
            corr(score, ans) as score__a,
            corr(score, acc) as score__c,
            corr(view_count, ans) as view_count__a,
            corr(view_count, acc) as view_count__c,
            corr(owner_reputation, ans) as owner_reputation__a,
            corr(owner_reputation, acc) as owner_reputation__c,
            corr(owner_age_days, ans) as owner_age_days__a,
            corr(owner_age_days, acc) as owner_age_days__c,
            corr(favorite_count, ans) as favorite_count__a,
            corr(favorite_count, acc) as favorite_count__c,
            corr(title_len, ans) as title_len__a,
            corr(title_len, acc) as title_len__c,
            corr(title_words, ans) as title_words__a,
            corr(title_words, acc) as title_words__c,
            corr(title_has_qmark, ans) as title_has_qmark__a,
            corr(title_has_qmark, acc) as title_has_qmark__c,
            corr(body_len, ans) as body_len__a,
            corr(body_len, acc) as body_len__c,
            corr(has_img_or_link, ans) as has_img_or_link__a,
            corr(has_img_or_link, acc) as has_img_or_link__c,
            corr(num_tags, ans) as num_tags__a,
            corr(num_tags, acc) as num_tags__c,
            corr(comment_count, ans) as comment_count__a,
            corr(comment_count, acc) as comment_count__c,
            corr(has_registered_owner, ans) as has_registered_owner__a,
            corr(has_registered_owner, acc) as has_registered_owner__c
        from feats
    )

-- unpivot the wide row into one row per feature, pairing its __a/__c columns
select
    feature,
    round(corr_with_answer, 4) as corr_with_answer,
    round(corr_with_accepted, 4) as corr_with_accepted
from
    corrs unpivot (
        (corr_with_answer, corr_with_accepted) for feature in (
            (has_code__a, has_code__c) as 'has_code',
            (score__a, score__c) as 'score',
            (view_count__a, view_count__c) as 'view_count',
            (owner_reputation__a, owner_reputation__c) as 'owner_reputation',
            (owner_age_days__a, owner_age_days__c) as 'owner_age_days',
            (favorite_count__a, favorite_count__c) as 'favorite_count',
            (title_len__a, title_len__c) as 'title_len',
            (title_words__a, title_words__c) as 'title_words',
            (title_has_qmark__a, title_has_qmark__c) as 'title_has_qmark',
            (body_len__a, body_len__c) as 'body_len',
            (has_img_or_link__a, has_img_or_link__c) as 'has_img_or_link',
            (num_tags__a, num_tags__c) as 'num_tags',
            (comment_count__a, comment_count__c) as 'comment_count',
            (has_registered_owner__a, has_registered_owner__c) as 'has_registered_owner'
        )
    )
order by abs(corr_with_accepted) desc
