-- ============================================================================
-- DEEPWORK ANALYTICS — MASTER DATABASE SCHEMA
-- Author: Tanish Jindal
-- Description: Complete 3NF relational model including User/TA RBAC, 
--              Live Triggers for focus tracking, and ACID Transactions.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS DeepWorkAnalytics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE DeepWorkAnalytics;

-- ----------------------------------------------------------------------------
-- 0. CLEANUP (Drop in reverse dependency order)
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS Buy_Reward;
DROP PROCEDURE IF EXISTS TransferPoints;
DROP TRIGGER IF EXISTS Prevent_Multiple_Active_Sessions;
DROP TRIGGER IF EXISTS Update_Session_Metrics;
DROP TRIGGER IF EXISTS Award_Bonus_Points;

DROP TABLE IF EXISTS Purchases;
DROP TABLE IF EXISTS Store_Items;
DROP TABLE IF EXISTS Activity_Logs;
DROP TABLE IF EXISTS Sessions;
DROP TABLE IF EXISTS Category_Keywords;
DROP TABLE IF EXISTS Website_Categories;
DROP TABLE IF EXISTS Topics;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Tutorial_Groups;

-- ----------------------------------------------------------------------------
-- 1. DOMAIN: USERS & TUTORIAL GROUPS
-- ----------------------------------------------------------------------------
CREATE TABLE Tutorial_Groups (
    tg_id INT AUTO_INCREMENT PRIMARY KEY,
    tg_number VARCHAR(10) NOT NULL UNIQUE,
    ta_name VARCHAR(100) NOT NULL
);

CREATE TABLE Users (
    u_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) DEFAULT 'password123',
    role ENUM('Admin', 'Student', 'TA') NOT NULL DEFAULT 'Student',
    total_bonus_points INT DEFAULT 0,
    tg_id INT NOT NULL,
    FOREIGN KEY (tg_id) REFERENCES Tutorial_Groups(tg_id),
    CONSTRAINT chk_positive_points CHECK (total_bonus_points >= 0)
);

-- ----------------------------------------------------------------------------
-- 2. DOMAIN: MASTER DATA (Topics & Categories)
-- ----------------------------------------------------------------------------
CREATE TABLE Topics (
    topic_id INT AUTO_INCREMENT PRIMARY KEY,
    topic_name VARCHAR(100) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    admin_id INT,
    FOREIGN KEY (admin_id) REFERENCES Users(u_id)
);

CREATE TABLE Website_Categories (
    wc_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    penalty_weight INT DEFAULT 0,
    admin_id INT,
    FOREIGN KEY (admin_id) REFERENCES Users(u_id)
);

CREATE TABLE Category_Keywords (
    ck_id INT AUTO_INCREMENT PRIMARY KEY,
    keyword VARCHAR(100) NOT NULL UNIQUE,
    wc_id INT NOT NULL,
    FOREIGN KEY (wc_id) REFERENCES Website_Categories(wc_id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 3. DOMAIN: CORE TRACKING (Sessions & Logs)
-- ----------------------------------------------------------------------------
CREATE TABLE Sessions (
    s_id INT AUTO_INCREMENT PRIMARY KEY,
    u_id INT NOT NULL,
    topic_id INT NOT NULL,
    start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    goal TEXT,
    final_score DECIMAL(5,2) DEFAULT 100.00,
    status ENUM('active', 'completed', 'timed_out') NOT NULL DEFAULT 'active',
    productive_time INT DEFAULT 0,
    distraction_time INT DEFAULT 0,
    FOREIGN KEY (u_id) REFERENCES Users(u_id) ON DELETE CASCADE,
    FOREIGN KEY (topic_id) REFERENCES Topics(topic_id),
    CONSTRAINT chk_score CHECK (final_score BETWEEN 0 AND 100),
    CONSTRAINT chk_session_time CHECK (end_time IS NULL OR end_time >= start_time)
);

CREATE TABLE Activity_Logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    s_id INT NOT NULL,
    ck_id INT NULL,
    window_title VARCHAR(255) NOT NULL,
    application_name VARCHAR(100),
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    duration INT DEFAULT 5,
    FOREIGN KEY (s_id) REFERENCES Sessions(s_id) ON DELETE CASCADE,
    FOREIGN KEY (ck_id) REFERENCES Category_Keywords(ck_id)
);

-- ----------------------------------------------------------------------------
-- 4. DOMAIN: VIRTUAL ECONOMY (Store)
-- ----------------------------------------------------------------------------
CREATE TABLE Store_Items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cost INT NOT NULL,
    icon VARCHAR(50)
);

CREATE TABLE Purchases (
    purchase_id INT AUTO_INCREMENT PRIMARY KEY,
    u_id INT NOT NULL,
    item_id INT NOT NULL,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (u_id) REFERENCES Users(u_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES Store_Items(item_id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 5. PERFORMANCE INDEXES (B-Trees)
-- ----------------------------------------------------------------------------
CREATE INDEX idx_session_logs ON Activity_Logs(s_id);
CREATE INDEX idx_user_sessions ON Sessions(u_id);
CREATE INDEX idx_keyword_search ON Category_Keywords(keyword);

-- ============================================================================
-- 6. DATABASE TRIGGERS (Live Automation)
-- ============================================================================
DELIMITER //

-- TRIGGER A: Anti-Cheat (One active session per user)
CREATE TRIGGER Prevent_Multiple_Active_Sessions
BEFORE INSERT ON Sessions
FOR EACH ROW
BEGIN
    DECLARE active_count INT;
    SELECT COUNT(*) INTO active_count FROM Sessions WHERE u_id = NEW.u_id AND status = 'active';
    
    IF active_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trigger Blocked: User already has an active session running.';
    END IF;
END; //

-- TRIGGER B: Live Analytics (Update score/times based on logs)
CREATE TRIGGER Update_Session_Metrics
AFTER INSERT ON Activity_Logs
FOR EACH ROW
BEGIN
    DECLARE cat_name VARCHAR(50);
    DECLARE p_weight INT;

    IF NEW.ck_id IS NOT NULL THEN
        SELECT wc.category_name, wc.penalty_weight INTO cat_name, p_weight
        FROM Category_Keywords ck
        JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
        WHERE ck.ck_id = NEW.ck_id;

        IF cat_name = 'Productive' THEN
            UPDATE Sessions SET productive_time = productive_time + NEW.duration WHERE s_id = NEW.s_id;
        ELSEIF cat_name = 'Distracting' THEN
            UPDATE Sessions 
            SET distraction_time = distraction_time + NEW.duration,
                final_score = GREATEST(0, final_score - p_weight) 
            WHERE s_id = NEW.s_id;
        END IF;
    END IF;
END; //

-- TRIGGER C: Gamification (Award points when session completes)
CREATE TRIGGER Award_Bonus_Points
AFTER UPDATE ON Sessions
FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status = 'active' THEN
        UPDATE Users 
        SET total_bonus_points = total_bonus_points + FLOOR(NEW.productive_time / 60)
        WHERE u_id = NEW.u_id;
    END IF;
END; //

-- ============================================================================
-- 7. ACID TRANSACTIONS (Row-Level Locking)
-- ============================================================================

-- TRANSACTION A: Buying a Reward safely
CREATE PROCEDURE Buy_Reward(IN student_id INT, IN store_item_id INT)
BEGIN
    DECLARE current_points INT;
    DECLARE item_cost INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT '❌ Transaction Failed: An error occurred. Safe ROLLBACK executed.' AS Result;
    END;

    START TRANSACTION;
    
    SELECT cost INTO item_cost FROM Store_Items WHERE item_id = store_item_id;
    
    -- ROW-LEVEL LOCK
    SELECT total_bonus_points INTO current_points 
    FROM Users WHERE u_id = student_id FOR UPDATE;
    
    IF current_points >= item_cost THEN
        UPDATE Users SET total_bonus_points = total_bonus_points - item_cost WHERE u_id = student_id;
        INSERT INTO Purchases (u_id, item_id) VALUES (student_id, store_item_id);
        
        COMMIT;
        SELECT '✅ Purchase Successful!' AS Result;
    ELSE
        ROLLBACK;
        SELECT '❌ Transaction Failed: Insufficient Points.' AS Result;
    END IF;
END; //

-- TRANSACTION B: Transferring points between students
CREATE PROCEDURE TransferPoints(IN sender_id INT, IN receiver_id INT, IN amount INT)
BEGIN
    DECLARE current_points INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT '❌ Transaction Failed: Safe ROLLBACK executed.' AS Result;
    END;

    START TRANSACTION;

    -- Lock both rows explicitly
    SELECT total_bonus_points INTO current_points FROM Users WHERE u_id = sender_id FOR UPDATE;
    SELECT total_bonus_points FROM Users WHERE u_id = receiver_id FOR UPDATE;

    IF current_points >= amount THEN
        UPDATE Users SET total_bonus_points = total_bonus_points - amount WHERE u_id = sender_id;
        UPDATE Users SET total_bonus_points = total_bonus_points + amount WHERE u_id = receiver_id;
        COMMIT;
        SELECT '✅ Transaction Successful: Points transferred.' AS Result;
    ELSE
        ROLLBACK;
        SELECT '❌ Transaction Failed: Sender has insufficient points.' AS Result;
    END IF;
END //

DELIMITER ;
