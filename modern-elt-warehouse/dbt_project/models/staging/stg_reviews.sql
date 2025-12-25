{{
    config(
        materialized='table',
        schema='olist_silver',
        tags=['staging'],
        description='Cleaned review data with sentiment scoring'
    )
}}

with source_data as (
    select
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        current_timestamp() as dbt_loaded_at
    from {{ source('olist', 'order_reviews') }}
),

cleaned as (
    select
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        dbt_loaded_at,
        -- Sentiment categorization based on score
        case
            when review_score = 5 then 'Very Positive'
            when review_score = 4 then 'Positive'
            when review_score = 3 then 'Neutral'
            when review_score = 2 then 'Negative'
            when review_score = 1 then 'Very Negative'
            else 'Unknown'
        end as sentiment,
        -- Response indicator
        case
            when review_answer_timestamp is not null then true
            else false
        end as seller_responded,
        -- Response time if applicable
        case
            when review_answer_timestamp is not null
            then timestamp_diff(
                review_answer_timestamp,
                review_creation_date,
                day
            )
            else null
        end as days_to_respond
    from source_data
    where order_id is not null
        and review_score is not null
)

select * from cleaned
