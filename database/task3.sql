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
    CONSTRAINT chk_positive_points CHECK (total_bonus_points >= 0)
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

-- Fast lookup for logs belonging to a specific session
CREATE INDEX idx_session_logs ON Activity_Logs(s_id);
-- Fast lookup for sessions by a specific user
CREATE INDEX idx_user_sessions ON Sessions(u_id);

CREATE INDEX idx_keyword_search ON Category_Keywords(keyword);