CREATE DATABASE IF NOT EXISTS DeepWorkAnalytics;
USE DeepWorkAnalytics;

-- 1. Tutorial_Groups (Base table)
CREATE TABLE Tutorial_Groups (
    tg_id INT AUTO_INCREMENT PRIMARY KEY,
    tg_number VARCHAR(10) NOT NULL UNIQUE,
    ta_name VARCHAR(100) NOT NULL
);

--2. Users (References Tutorial_Groups)
CREATE TABLE Users (
    u_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role ENUM('Admin', 'Student', 'TA') NOT NULL DEFAULT 'Student',
    total_bonus_points INT DEFAULT 0,
    tg_id INT NOT NULL,
    FOREIGN KEY (tg_id) REFERENCES Tutorial_Groups(tg_id)
);

-- 3. Topics (References Users - Admin who created it)
CREATE TABLE Topics (
    topic_id INT AUTO_INCREMENT PRIMARY KEY,
    topic_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    admin_id INT,
    FOREIGN KEY (admin_id) REFERENCES Users(u_id)
);

-- 4. Website_Categories (References Users - Admin who defined rules)
CREATE TABLE Website_Categories (
    wc_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL, -- eg 'Productive', 'Distracting'
    penalty_weight INT DEFAULT 0,
    admin_id INT,
    FOREIGN KEY (admin_id) REFERENCES Users(u_id)
);

CREATE TABLE Category_Keywords (
    ck_id INT AUTO_INCREMENT PRIMARY KEY,
    keyword VARCHAR(100) NOT NULL UNIQUE, -- eg 'youtube', 'netflix', 'vscode'
    wc_id INT NOT NULL,
    FOREIGN KEY (wc_id) REFERENCES Website_Categories(wc_id) ON DELETE CASCADE
);

-- 5. Sessions (References Users and Topics)
CREATE TABLE Sessions (
    s_id INT AUTO_INCREMENT PRIMARY KEY,
    u_id INT NOT NULL,
    topic_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    goal TEXT,
    final_score DECIMAL(5,2) DEFAULT 0.00,
    status ENUM('active', 'completed', 'timed_out') NOT NULL DEFAULT 'active',
    productive_time INT DEFAULT 0,
    distraction_time INT DEFAULT 0,
    FOREIGN KEY (u_id) REFERENCES Users(u_id),
    FOREIGN KEY (topic_id) REFERENCES Topics(topic_id),
    -- Constraint: Score must be between 0 and 100
    CONSTRAINT chk_score CHECK (final_score BETWEEN 0 AND 100),
    -- Constraint: Session end cannot be before start
    CONSTRAINT chk_session_time CHECK (end_time IS NULL OR end_time >= start_time)
);
-- Table 6: Activity_Logs (References Keywords instead of Categories)
CREATE TABLE Activity_Logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    s_id INT NOT NULL,
    ck_id INT,
    window_title VARCHAR(255) NOT NULL,
    application_name VARCHAR(100),
    timestamp DATETIME NOT NULL,
    duration INT DEFAULT 5,
    FOREIGN KEY (s_id) REFERENCES Sessions(s_id) ON DELETE CASCADE,
    FOREIGN KEY (ck_id) REFERENCES Category_Keywords(ck_id)
);


-- Fast lookup for logs belonging to a specific session
CREATE INDEX idx_session_logs ON Activity_Logs(s_id);
-- Fast lookup for sessions by a specific user
CREATE INDEX idx_user_sessions ON Sessions(u_id);

CREATE INDEX idx_keyword_search ON Category_Keywords(keyword);

-- 1. Create Tutorial Groups
INSERT INTO Tutorial_Groups (tg_number, ta_name) VALUES 
('T9', 'TA 1'),
('T10', 'TA 2');

-- 2. Created an Admin and Students
INSERT INTO Users (name, email, role, tg_id) VALUES 
('Tanish Admin', 'tanish.admin@iiitd.ac.in', 'Admin', 1),
('Student User', 'student@iiitd.ac.in', 'Student', 1);

-- 3. Created  Study Topics
INSERT INTO Topics (topic_name, admin_id) VALUES 
('DBMS Project', 1),
('DSA Practice', 1),
('Midsem Prep', 1);
('Endsem Prep', 1);

-- 4. Created Parent Categories
INSERT INTO Website_Categories (category_name, penalty_weight, admin_id) VALUES 
('Productive', 0, 1), 
('Distracting', 15, 1);

-- 5. Created Keywords linked to Categories
INSERT INTO Category_Keywords (keyword, wc_id) VALUES 
('VS Code', 1), 
('LeetCode', 1), 
('Stack Overflow', 1),
('YouTube', 2), 
('Netflix', 2),
('Facebook',2),
('Instagram',2);


-- SQL QUERIES 

-- Basic Aggregations
--1. Topic Popularity
SELECT 
    t.topic_name, 
    COUNT(s.s_id) AS total_sessions
FROM Topics t
LEFT JOIN Sessions s ON t.topic_id = s.topic_id
GROUP BY t.topic_name
ORDER BY total_sessions DESC;
--We use a LEFT JOIN here so that even if a topic has 0 sessions, it still shows up on the report

--2 Personal History
--Goal: Retrieve all sessions for a specific student (e.g., student with u_id = 2)
SELECT 
    s_id, 
    start_time, 
    end_time, 
    goal, 
    status, 
    final_score,
    productive_time,
    distraction_time
FROM Sessions
WHERE u_id = 2 
ORDER BY start_time DESC;

--3. Active Sessions
--Goal: List currently running sessions, including the student's name and what they are studying.
SELECT 
    u.name AS student_name, 
    t.topic_name, 
    s.start_time, 
    s.goal
FROM Sessions s
JOIN Users u ON s.u_id = u.u_id
JOIN Topics t ON s.topic_id = t.topic_id
WHERE s.status = 'active';

--Performance & Ranking

--4.Top Performers
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


-- Task 5 

USE DeepWorkAnalytics;

-- 1. Ensure sessions start with a perfect score of 100
ALTER TABLE Sessions MODIFY final_score DECIMAL(5,2) DEFAULT 100.00;

DELIMITER //

-- DROP existing triggers if you are re-running this script
DROP TRIGGER IF EXISTS Prevent_Multiple_Active_Sessions //
DROP TRIGGER IF EXISTS Update_Session_Metrics //
DROP TRIGGER IF EXISTS Award_Bonus_Points //

-- -----------------------------------------------------------------------------
-- TRIGGER 1: THE BEGINNING (Anti-Cheat / Validation)
-- -----------------------------------------------------------------------------
CREATE TRIGGER Prevent_Multiple_Active_Sessions
BEFORE INSERT ON Sessions
FOR EACH ROW
BEGIN
    DECLARE active_count INT;
    
    SELECT COUNT(*) INTO active_count 
    FROM Sessions 
    WHERE u_id = NEW.u_id AND status = 'active';
    
    IF active_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Trigger Blocked: User already has an active session running.';
    END IF;
END; //

-- -----------------------------------------------------------------------------
-- TRIGGER 2: THE MIDDLE (Live Analytics)
-- -----------------------------------------------------------------------------
CREATE TRIGGER Update_Session_Metrics
AFTER INSERT ON Activity_Logs
FOR EACH ROW
BEGIN
    DECLARE cat_name VARCHAR(50);
    DECLARE p_weight INT;

    SELECT wc.category_name, wc.penalty_weight INTO cat_name, p_weight
    FROM Category_Keywords ck
    JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
    WHERE ck.ck_id = NEW.ck_id;

    IF cat_name = 'Productive' THEN
        UPDATE Sessions 
        SET productive_time = productive_time + NEW.duration
        WHERE s_id = NEW.s_id;
    ELSEIF cat_name = 'Distracting' THEN
        UPDATE Sessions 
        SET distraction_time = distraction_time + NEW.duration,
            final_score = GREATEST(0, final_score - p_weight) 
        WHERE s_id = NEW.s_id;
    END IF;
END; //

-- -----------------------------------------------------------------------------
-- TRIGGER 3: THE END (Gamification / Rewards)
-- -----------------------------------------------------------------------------
CREATE TRIGGER Award_Bonus_Points
AFTER UPDATE ON Sessions
FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status = 'active' THEN
        -- Award 1 bonus point for every 60 seconds of productive time
        UPDATE Users 
        SET total_bonus_points = total_bonus_points + FLOOR(NEW.productive_time / 60)
        WHERE u_id = NEW.u_id;
    END IF;
END; //

DELIMITER ;

-- 1. Create a table to track reward purchases
CREATE TABLE Store_Purchases (
    purchase_id INT AUTO_INCREMENT PRIMARY KEY,
    u_id INT,
    item_name VARCHAR(100),
    cost INT,
    purchase_date DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Give Student User (u_id = 2) exactly 50 bonus points for this demo
UPDATE Users SET total_bonus_points = 50 WHERE u_id = 2;


-- Transactions
DELIMITER //

CREATE PROCEDURE Buy_Reward(IN student_id INT, IN reward_name VARCHAR(100), IN item_cost INT)
BEGIN
    DECLARE current_points INT;
    
    -- Start the transaction!
    START TRANSACTION;
    
    -- Get the student's current balance
    SELECT total_bonus_points INTO current_points 
    FROM Users WHERE u_id = student_id;
    
    -- Check if they have enough points
    IF current_points >= item_cost THEN
        -- 1. Deduct the points
        UPDATE Users SET total_bonus_points = total_bonus_points - item_cost WHERE u_id = student_id;
        
        -- 2. Give them the item
        INSERT INTO Store_Purchases (u_id, item_name, cost) VALUES (student_id, reward_name, item_cost);
        
        -- Everything worked! Save it permanently.
        COMMIT;
        SELECT 'Purchase Successful!' AS Result;
    ELSE
        -- Not enough points! Undo any changes and cancel.
        ROLLBACK;
        SELECT 'Transaction Failed: Insufficient Points.' AS Result;
    END IF;
END; //

DELIMITER ;

USE DeepWorkAnalytics;

-- Add the missing password column
ALTER TABLE Users ADD COLUMN password VARCHAR(255) DEFAULT 'password123';

-- Set your custom Admin password
UPDATE Users SET password = 'admin_password' WHERE u_id = 1;

USE DeepWorkAnalytics;

-- Allow ck_id to be NULL when the tracker first logs the activity
ALTER TABLE Activity_Logs MODIFY ck_id INT NULL;


-- 1. Create the Store Items Table
CREATE TABLE Store_Items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cost INT NOT NULL,
    icon VARCHAR(50)
);

-- 2. Create the Purchase History Table
CREATE TABLE Purchases (
    purchase_id INT AUTO_INCREMENT PRIMARY KEY,
    u_id INT,
    item_id INT,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (u_id) REFERENCES Users(u_id),
    FOREIGN KEY (item_id) REFERENCES Store_Items(item_id)
);

-- 3. Stock the Store!
INSERT INTO Store_Items (name, description, cost, icon) VALUES 
('Custom Profile Badges', 'Badges like "Algorithm Ace" or "Deep Work Demon" that sit next to your name.', 300, '🏅'),
('"Night Owl" Theme', 'Unlocks a pure-black dark mode for the dashboard.', 500, '🌙'),
('Golden Username', 'Your name glows gold on the Global Leaderboard.', 1000, '✨'),
('1-on-1 Mentorship Session', 'A 15-minute private Zoom call with the TA.', 1500, '🤝'),
('Free Coffee Voucher', 'A coupon code for the campus cafe.', 2000, '☕'),
('Assignment 24-Hour Extension', 'A "get out of jail free" card for a late submission.', 2500, '⏰'),
('Pizza Slice', 'A free slice of pizza to fuel your next study session.', 3000, '🍕'),
('Skip One Small Quiz', 'The ultimate grind goal. Pass "Go" and collect your A.', 5000, '👑');

--TRANSACTION 2
-- 1. Change the delimiter so MySQL doesn't get confused by the semicolons inside the procedure
DELIMITER //

-- 2. Create the reusable Stored Procedure
CREATE PROCEDURE TransferPoints(IN sender_id INT, IN receiver_id INT, IN amount INT)
BEGIN
    -- ==========================================
    -- THE CATCH BLOCK (Rollback Logic)
    -- ==========================================
    -- If ANY error happens below (e.g., database crash, lost connection, constraint failure), this block triggers automatically.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT '❌ Transaction Failed: An error occurred. Safe ROLLBACK executed.' AS Transaction_Status;
    END;

    -- ==========================================
    -- THE TRY BLOCK (The Transaction)
    -- ==========================================
    START TRANSACTION;

    -- Step 1: Lock both rows so nobody else can touch them during the transfer (Isolation)
    SELECT total_bonus_points FROM Users WHERE u_id IN (sender_id, receiver_id) FOR UPDATE;

    -- Step 2: Deduct points from the sender
    UPDATE Users 
    SET total_bonus_points = total_bonus_points - amount 
    WHERE u_id = sender_id;

    -- Step 3: Add points to the receiver
    UPDATE Users 
    SET total_bonus_points = total_bonus_points + amount 
    WHERE u_id = receiver_id;

    -- Step 4: If we make it here without crashing, save it permanently!
    COMMIT;
    
    SELECT '✅ Transaction Successful: Points safely transferred.' AS Transaction_Status;

END //

-- 3. Reset the delimiter back to normal
DELIMITER ;

-- Transfer 100 points from User 2 (Aarav) to User 3 (Parth)
CALL TransferPoints(2, 3, 100);

ALTER TABLE Users 
ADD CONSTRAINT chk_positive_points 
CHECK (total_bonus_points >= 0);