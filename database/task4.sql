---4.Top Performers
--Goal: Find the top 5 students in a specific topic (e.g., 'DSA Practice') who have exactly zero distractions.
SELECT 
    u.name AS student_name, 
    COUNT(al.log_id) AS total_activities_logged,
    SUM(al.duration) AS total_time_spent
FROM Users u
JOIN Sessions s ON u.u_id = s.u_id
JOIN Topics t ON s.topic_id = t.topic_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
WHERE t.topic_name = 'Data Structures and Algorithms'
GROUP BY u.u_id, u.name
-- The HAVING clause filters out anyone who has even 1 distracting log
HAVING SUM(CASE WHEN wc.category_name = 'Distracting' THEN 1 ELSE 0 END) = 0
ORDER BY total_time_spent DESC
LIMIT 5;

--5. Leaderboard
--Goal: Rank students by their total productive focus time.
SELECT 
    u.name AS student_name, 
    tg.tg_number AS tutorial_group,
    -- Calculate total time spent on Productive sites
    SUM(CASE WHEN wc.category_name = 'Productive' THEN al.duration ELSE 0 END) AS productive_time,
    -- Calculate total time spent on Distracting sites for comparison
    SUM(CASE WHEN wc.category_name = 'Distracting' THEN al.duration ELSE 0 END) AS distracting_time
FROM Users u
JOIN Tutorial_Groups tg ON u.tg_id = tg.tg_id
JOIN Sessions s ON u.u_id = s.u_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
GROUP BY u.u_id, u.name, tg.tg_number
ORDER BY productive_time DESC;

--6. Efficiency Check
--Goal: Identify sessions that are sufficiently long (e.g., over 30 units of time) where the user was highly productive (efficiency over 90%)
SELECT 
    s.s_id, 
    u.name AS student_name, 
    s.goal,
    SUM(al.duration) AS total_session_time,
    -- Calculate efficiency percentage: (Productive Time / Total Time) * 100
    (SUM(CASE WHEN wc.category_name = 'Productive' THEN al.duration ELSE 0 END) / SUM(al.duration)) * 100 AS efficiency_percentage
FROM Sessions s
JOIN Users u ON s.u_id = u.u_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
GROUP BY s.s_id, u.name, s.goal
-- Filter for sessions longer than a threshold (e.g., 30 time units) with > 90% efficiency
HAVING total_session_time > 30 
   AND efficiency_percentage > 90
ORDER BY efficiency_percentage DESC;

--Advanced Analytics queries
--7. Group Benchmarking
--Goal: Calculate average focus score/time for Tutorial Group T1 vs T2
--(Since haven't added the automatic final score trigger yet, so i will dynamically calculate their "Productive Time" average
SELECT 
    tg.tg_number AS tutorial_group,
    COUNT(DISTINCT s.s_id) AS total_sessions,
    -- Calculate the average productive time per group
    AVG(CASE WHEN wc.category_name = 'Productive' THEN al.duration ELSE 0 END) AS avg_productive_time
FROM Tutorial_Groups tg
JOIN Users u ON tg.tg_id = u.tg_id
JOIN Sessions s ON u.u_id = s.u_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
GROUP BY tg.tg_number
ORDER BY avg_productive_time DESC;

--8. Distraction Analysis
--Goal: Most common distracting websites per topic
SELECT 
    t.topic_name, 
    ck.keyword AS distracting_website, 
    COUNT(al.log_id) AS distraction_hits
FROM Topics t
JOIN Sessions s ON t.topic_id = s.topic_id
JOIN Activity_Logs al ON s.s_id = al.s_id
JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
-- We only care about the distracting logs!
WHERE wc.category_name = 'Distracting'
GROUP BY t.topic_name, ck.keyword
ORDER BY t.topic_name ASC, distraction_hits DESC;

--9. Productivity Trends
--Goal: Track individual student's focus score over time.
--(used the DATE() function here to group timestamps by day, showing a timeline of their habits).

SELECT 
    DATE(s.start_time) AS study_date,
    u.name AS student_name,
    SUM(CASE WHEN wc.category_name = 'Productive' THEN al.duration ELSE 0 END) AS daily_productive_time,
    SUM(CASE WHEN wc.category_name = 'Distracting' THEN al.duration ELSE 0 END) AS daily_distraction_time
FROM Users u
JOIN Sessions s ON u.u_id = s.u_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
WHERE u.u_id = 1 -- Change this to any student's u_id to view their specific trend
GROUP BY study_date, u.name
ORDER BY study_date ASC;

--10. Topic Correlation
--Goal: Topics with the highest average distraction rates.
--(This query calculates a "Distraction Rate Percentage" by dividing the bad time by the total time)

SELECT 
    t.topic_name,
    SUM(CASE WHEN wc.category_name = 'Distracting' THEN al.duration ELSE 0 END) AS total_distraction_time,
    SUM(al.duration) AS total_time,
    -- Calculate the Distraction Rate %
    (SUM(CASE WHEN wc.category_name = 'Distracting' THEN al.duration ELSE 0 END) / SUM(al.duration)) * 100 AS distraction_rate_percentage
FROM Topics t
JOIN Sessions s ON t.topic_id = s.topic_id
JOIN Activity_Logs al ON s.s_id = al.s_id
LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
GROUP BY t.topic_name
ORDER BY distraction_rate_percentage DESC;

--11. Peak Usage Hours
--Goal: Most active time of day across all students.
--(This uses the HOUR() function to extract just the hour from the timestamp (0-23) to see when the server is busiest).
SELECT 
    HOUR(al.timestamp) AS hour_of_day, 
    COUNT(al.log_id) AS total_activity_volume
FROM Activity_Logs al
GROUP BY hour_of_day
ORDER BY total_activity_volume DESC;

--Administrative Queries
--12. Inactive Users
--Goal: Find students who haven't studied in the past 7 days.
--(We use a Subquery with NOT IN to filter out anyone who has a recent session).
SELECT 
    u.u_id, 
    u.name AS student_name, 
    u.email
FROM Users u
WHERE u.role = 'Student' 
  AND u.u_id NOT IN (
      -- This inner query finds everyone who HAS studied recently
      SELECT DISTINCT u_id 
      FROM Sessions 
      WHERE start_time >= DATE_SUB(NOW(), INTERVAL 7 DAY)
  );

--13. Score Distribution (Histogram)
--Goal: Group focus scores into buckets (Excellent, Good, Average, Poor).
--(Since we don't have the final score trigger yet, we first calculate the score dynamically in a "Derived Table" (the FROM (...) AS SessionScores part), and then use a CASE statement to drop those scores into buckets!)
SELECT 
    CASE 
        WHEN focus_score >= 90 THEN 'Excellent (90-100%)'
        WHEN focus_score >= 70 THEN 'Good (70-89%)'
        WHEN focus_score >= 50 THEN 'Average (50-69%)'
        ELSE 'Poor (<50%)'
    END AS score_bucket,
    COUNT(s_id) AS total_sessions
FROM (
    -- Derived Table: Calculate the percentage score for every session first
    SELECT 
        s.s_id,
        IFNULL((SUM(CASE WHEN wc.category_name = 'Productive' THEN al.duration ELSE 0 END) / NULLIF(SUM(al.duration), 0)) * 100, 0) AS focus_score
    FROM Sessions s
    LEFT JOIN Activity_Logs al ON s.s_id = al.s_id
    LEFT JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
    LEFT JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
    GROUP BY s.s_id
) AS SessionScores
GROUP BY score_bucket
ORDER BY score_bucket;

--14. Topic Adoption
--Goal: Usage comparison of new vs legacy topics.
SELECT 
    CASE WHEN t.is_active = 1 THEN 'Active (New) Topics' ELSE 'Archived (Legacy) Topics' END AS topic_status,
    COUNT(DISTINCT t.topic_id) AS total_topics_in_system,
    COUNT(s.s_id) AS total_sessions_run
FROM Topics t
LEFT JOIN Sessions s ON t.topic_id = s.topic_id
GROUP BY t.is_active;

--15. Concurrent Session Audit
--Goal: Detect violations of the "one-active-session" rule.
--(If a student accidentally runs the Python script twice, they might have two 'active' sessions at the same time. This query catches them by counting active sessions and filtering with HAVING)
SELECT 
    u.u_id, 
    u.name AS student_name, 
    COUNT(s.s_id) AS active_session_count
FROM Users u
JOIN Sessions s ON u.u_id = s.u_id
WHERE s.status = 'active'
GROUP BY u.u_id, u.name
-- The crucial filter: only show students breaking the rule
HAVING active_session_count > 1;