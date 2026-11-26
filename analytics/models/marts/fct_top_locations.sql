-- Grain: one row per job_location (top 10 by postings)
SELECT
    job_location,
    COUNT(*) AS postings
FROM {{ ref('stg_job_postings') }}
GROUP BY job_location
ORDER BY postings DESC
LIMIT 10