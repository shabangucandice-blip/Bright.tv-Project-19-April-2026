select * from `workspace`.`default`.`Ishe_an_view` limit 100;
select * from `workspace`.`default`.`Ishe_subscribers0` limit 100;

select 
  --Join my tables using left join (Base table.
  v.*,
  s.Age,
  s.Province,
  s.Race,
  s.Gender
from `workspace`.`default`.`Ishe_an_view` v
left join `workspace`.`default`.`Ishe_subscribers0` s
  on v.UserID = s.UserID;


-----------------------------------------------------------------------------

SELECT 
  v.UserID,
  v.Channel2 as Channel,
  v.record_date_sast,
  v.record_time_sast,
  
  -- Keep original HH:MM:SS format for Excel pivoting
  v.`Duration 2` as Duration,
  
  -- Subscriber Demographics (with NULL handling)
  COALESCE(s.Age, 32) as Age,
  COALESCE(s.Province, 'unkown') as Province,
  COALESCE(s.Race, 'Other') as Race,
  COALESCE(s.Gender, 'Unknown') as Gender,
  
  -- Date/Time Enrichments
  TO_DATE(v.record_date_sast, 'd-MMM-yyyy') as Record_Date,
  DATE_FORMAT(TO_DATE(v.record_date_sast, 'd-MMM-yyyy'), 'EEEE') as Day_of_Week,
  DATE_FORMAT(TO_DATE(v.record_date_sast, 'd-MMM-yyyy'), 'MMMM') as Month_Name,
  
  -- Time Buckets
  CASE 
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 5 AND 11 THEN '1. Morning (5AM-11AM)'
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 12 AND 16 THEN '2. Afternoon (12PM-4PM)'
    WHEN CAST(SUBSTRING(v.record_time_sast, 1, 2) AS INT) BETWEEN 17 AND 21 THEN '3. Evening (5PM-9PM)'
    ELSE '4. Night (10PM-4AM)'
  END as Time_Bucket,
  
  -- Age Bands (with NULL handling)
  CASE 
    WHEN s.Age IS NULL THEN '8. Unknown'
    WHEN s.Age < 18 THEN 'Minors. Under 18'
    WHEN s.Age BETWEEN 18 AND 24 THEN 'Young adults. 18-24' 
    WHEN s.Age BETWEEN 25 AND 34 THEN 'Millennials. 25-34'
    WHEN s.Age BETWEEN 35 AND 44 THEN 'Established. 35-44'
    WHEN s.Age BETWEEN 45 AND 54 THEN 'Mature adults. 45-54'
    WHEN s.Age BETWEEN 55 AND 64 THEN 'Pre-retirement. 55-64'
    WHEN s.Age BETWEEN 65 AND 89 THEN 'Retirement. 65-89'
    WHEN s.Age BETWEEN 90 AND 114 THEN 'Golden'
    ELSE '8. Unknown'
  END as Age_Band,
  
  -- Weekend Flag
  CASE 
    WHEN DAYOFWEEK(TO_DATE(v.record_date_sast, 'd-MMM-yyyy')) IN (1, 7) THEN 'Weekend'
    ELSE 'Weekday'
  END as Day_Type

FROM `workspace`.`default`.`Ishe_an_view` v
LEFT JOIN `workspace`.`default`.`Ishe_subscribers0` s
  ON v.UserID = s.UserID;

-----------------------------------------------------------------------------------------------------------
Subscriber table code : 
-----------------------------------------------------------------------------------------------------------
select * from `kenzowealth`.`default`.`Subscribers_5`;

--Check number of provinces 
select distinct Province from `kenzowealth`.`default`.`Subscribers_5`;

-- Address none values under the column -Province 

SELECT 
  CASE 
    WHEN LOWER(TRIM(Province)) = 'none' THEN 'Unknown'
    ELSE Province
  END AS Province
FROM `kenzowealth`.`default`.`Subscribers_5`;


--Fix casing on the column -Race

UPDATE `kenzowealth`.`default`.`Subscribers_5`
SET Race = CASE
    WHEN LOWER(TRIM(Race)) = 'white' THEN 'White'
    WHEN LOWER(TRIM(Race)) = 'black' THEN 'Black'
    WHEN LOWER(TRIM(Race)) = 'coloured' THEN 'Colored'
    WHEN LOWER(TRIM(Race)) = 'other' THEN 'Other'
    WHEN LOWER(TRIM(Race)) = 'indian_asian' THEN 'Indian_Asian'
    ELSE Race
END; 
-----------------------------------------

--replace none values under gender with other and fix casing 

UPDATE `kenzowealth`.`default`.`Subscribers_5`
SET Gender = CASE
    WHEN LOWER(TRIM(Gender)) = 'male' THEN 'Male'
    WHEN LOWER(TRIM(Gender)) = 'female' THEN 'Female'
    WHEN LOWER(TRIM(Gender)) = 'none' THEN 'Other'
    ELSE Gender
END;
-------------------------------------------------------------------------
SELECT 
  UserID,
  Age,
  CASE 
    WHEN LOWER(TRIM(Province)) = 'none' THEN 'Unknown'
    ELSE Province
  END AS Province,
  CASE
    WHEN LOWER(TRIM(Race)) = 'white' THEN 'White'
    WHEN LOWER(TRIM(Race)) = 'black' THEN 'Black'
    WHEN LOWER(TRIM(Race)) = 'coloured' THEN 'Colored'
    WHEN LOWER(TRIM(Race)) = 'other' THEN 'Other'
    WHEN LOWER(TRIM(Race)) = 'indian_asian' THEN 'Indian_Asian'
    ELSE Race
  END AS Race,
  CASE
    WHEN LOWER(TRIM(Gender)) = 'male' THEN 'Male'
    WHEN LOWER(TRIM(Gender)) = 'female' THEN 'Female'
    WHEN LOWER(TRIM(Gender)) = 'none' THEN 'Other'
    ELSE Gender
  END AS Gender
FROM `kenzowealth`.`default`.`Subscribers_5`;

----------------------------------------------------------------

  --performed basic hygiene on the viewership table 
  --------------------------------------------------------------

  --format Duration 2
select 
  UserID,
  Channel2,
  RecordDate2,
  record_sast,
  date_format(`Duration 2`, 'HH:mm:ss') as Duration_hms
from `kenzowealth`.`default`.`viewer_11`
limit 100;

--perform basic hygiene, trims ....

select
  cast(trim(UserID) as bigint) as UserID,
  trim(Channel2) as Channel2,
  trim(RecordDate2) as RecordDate2,
  trim(record_sast) as record_sast,
  date_format(trim(`Duration 2`), 'HH:mm:ss') as Duration_hms
from `kenzowealth`.`default`.`viewer_11`;

--Rename  Column names for consistency..
select
  cast(trim(UserID) as bigint) as user_id,
  trim(Channel2) as channel_name,
  trim(RecordDate2) as record_date,
  trim(record_sast) as record_sast,
  date_format(trim(`Duration 2`), 'HH:mm:ss') as duration_hms
from `kenzowealth`.`default`.`viewer_11`;

--address duplicates , trailing /leading spaces ...
select
  cast(trim(UserID) as bigint) as user_id,
  trim(Channel2) as channel_name,
  trim(RecordDate2) as record_date,
  trim(record_sast) as record_sast,
  date_format(trim(`Duration 2`), 'HH:mm:ss') as duration_hms
from `kenzowealth`.`default`.`viewer_11`
group by
  user_id,
  channel_name,
  record_date,
  record_sast,
  duration_hms;

  --address trails and casing variations under the column channel_name...
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport'
    ) then 'Supersport Live Events'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    else trim(Channel2)
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
limit 100;

-- Exclude non existant channels that inflate count...
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport'
    ) then 'Supersport Live Events'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    else trim(Channel2)
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
where lower(trim(Channel2)) not in ('break in transmission', 'dstv events 1')
limit 100;
-- Group related channels under the same brand family
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport',
      'supersport blitz'
    ) then 'Supersport'
    when lower(trim(Channel2)) in (
      'channel o',
      'mk'
    ) then 'Channel O / MK'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    else trim(Channel2)
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
where lower(trim(Channel2)) not in ('break in transmission', 'dstv events 1')
limit 100;

--  exclude all null or blank channels
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport',
      'supersport blitz'
    ) then 'Supersport'
    when lower(trim(Channel2)) in (
      'channel o',
      'mk'
    ) then 'Channel O / MK'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    else trim(Channel2)
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
where lower(trim(Channel2)) not in ('break in transmission', 'dstv events 1')
  and trim(Channel2) is not null
  and trim(Channel2) <> ''
limit 100;

-- exclude excessively rare channels (Wimbledon, Sawsee)
-- exclude excessively rare channels (Wimbledon, Sawsee)
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport',
      'supersport blitz'
    ) then 'Supersport'
    when lower(trim(Channel2)) in (
      'channel o',
      'mk'
    ) then 'Channel O / MK'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    else trim(Channel2)
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
where lower(trim(Channel2)) not in (
    'break in transmission', 
    'dstv events 1', 
    'wimbledon', 
    'sawsee'
  )
  and trim(Channel2) is not null
  and trim(Channel2) <> ''
limit 100;
-- Address inconsistent capitalisation ..
-- Address inconsistent capitalisation and enforce uniformity across all channels
select
  cast(trim(UserID) as bigint) as user_id,
  case
    when lower(trim(Channel2)) in (
      'supersport live events',
      'supersport live',
      'supersport events',
      'supersport',
      'supersport blitz'
    ) then 'Supersport'
    when lower(trim(Channel2)) in (
      'channel o',
      'mk'
    ) then 'Channel O / MK'
    when lower(trim(Channel2)) in (
      'sabc 1',
      'sabc1',
      'sabc one'
    ) then 'SABC 1'
    when lower(trim(Channel2)) in (
      'sabc 2',
      'sabc2',
      'sabc two'
    ) then 'SABC 2'
    when lower(trim(Channel2)) in (
      'sabc 3',
      'sabc3',
      'sabc three'
    ) then 'SABC 3'
    when lower(trim(Channel2)) in (
      'etv',
      'e-tv',
      'e tv'
    ) then 'eTV'
    when lower(trim(Channel2)) in (
      'mzansi magic',
      'mzansi',
      'mzansi magik'
    ) then 'Mzansi Magic'
    when lower(trim(Channel2)) in (
      'icc cricket world cup',
      'icc world cup',
      'icc cricket wc'
    ) then 'ICC Cricket World Cup'
    else initcap(trim(Channel2))
  end as channel_name,
  trim(RecordDate2) as record_time_utc,
  unix_timestamp(trim(`Duration 2`), 'yyyy-MM-dd HH:mm:ss') as watch_seconds
from `kenzowealth`.`default`.`viewer_11`
where lower(trim(Channel2)) not in (
    'break in transmission', 
    'dstv events 1', 
    'wimbledon', 
    'sawsee'
  )
  and trim(Channel2) is not null
  and trim(Channel2) <> ''
limit 100;
----------------------
--Merge query 
----------------------
with cleaned as (
  select
    cast(trim(UserID) as bigint) as user_id,
    case
      when lower(trim(Channel2)) in (
        'supersport live events', 'supersport live', 'supersport events', 'supersport', 'supersport blitz'
      ) then 'Supersport'
      when lower(trim(Channel2)) in ('channel o', 'mk') then 'Channel O / MK'
      when lower(trim(Channel2)) in ('sabc 1', 'sabc1', 'sabc one') then 'SABC 1'
      when lower(trim(Channel2)) in ('sabc 2', 'sabc2', 'sabc two') then 'SABC 2'
      when lower(trim(Channel2)) in ('sabc 3', 'sabc3', 'sabc three') then 'SABC 3'
      when lower(trim(Channel2)) in ('etv', 'e-tv', 'e tv') then 'eTV'
      when lower(trim(Channel2)) in ('mzansi magic', 'mzansi', 'mzansi magik') then 'Mzansi Magic'
      when lower(trim(Channel2)) in ('icc cricket world cup', 'icc world cup', 'icc cricket wc') then 'ICC Cricket World Cup'
      else initcap(trim(Channel2))
    end as channel_name,
    trim(RecordDate2) as record_time_utc,
    trim(record_sast) as record_sast,
    date_format(trim(`Duration 2`), 'HH:mm:ss') as duration_hms
  from `kenzowealth`.`default`.`viewer_11`
  where lower(trim(Channel2)) not in (
    'break in transmission', 'dstv events 1', 'wimbledon', 'sawsee'
  )
    and trim(Channel2) is not null
    and trim(Channel2) <> ''
)
select * except(record_time_utc)
from cleaned
group by user_id, channel_name, record_sast, duration_hms


















---------
