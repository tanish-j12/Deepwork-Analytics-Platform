const db = require('../config/db');

// 1. GET ALL USERS (Read)
exports.getAllUsers = async (req, res) => {
    try {
        const sql = `
            SELECT u_id, name, email, role, tg_id, total_bonus_points 
            FROM Users 
            ORDER BY u_id DESC
        `;
        const [users] = await db.query(sql);
        res.status(200).json({ success: true, data: users });
    } catch (err) {
        console.error("Admin Fetch Users Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// 2. PROVISION NEW USER (Create)
exports.createUser = async (req, res) => {
    const { name, email, tg_id, password } = req.body;

    try {
        // Enforce data integrity: Admin can only create 'Student' roles via this portal
        const sql = `
            INSERT INTO Users (name, email, password, role, tg_id, total_bonus_points) 
            VALUES (?, ?, ?, 'Student', ?, 0)
        `;
        
        await db.query(sql, [name, email, password, tg_id]);
        
        res.status(201).json({ success: true, message: "Student account provisioned successfully!" });
    } catch (err) {
        console.error("Admin Create User Error:", err);
        // Catch duplicate email errors from MySQL
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({ success: false, message: "A user with this email already exists." });
        }
        res.status(500).json({ success: false, message: "Failed to create user." });
    }
};

// ==========================================
// 3. SYSTEM ANALYTICS (Global Aggregations)
// ==========================================
exports.getSystemStats = async (req, res) => {
    try {
        // Fire all three global queries concurrently for maximum speed!
        const [
            [totalTimeResult],
            [totalPointsResult],
            [topGroupResult]
        ] = await Promise.all([
            // Query 1: Total Deep Work across the entire platform
            db.query(`SELECT SUM(productive_time) AS platform_total_time FROM Sessions`),
            
            // Query 2: Total economy size (Points currently held by students)
            db.query(`SELECT SUM(total_bonus_points) AS platform_total_points FROM Users WHERE role = 'Student'`),
            
            // Query 3: Most Productive Tutorial Group (Double JOIN)
            db.query(`
                SELECT u.tg_id, SUM(s.productive_time) as group_time 
                FROM Sessions s
                JOIN Users u ON s.u_id = u.u_id
                WHERE u.tg_id IS NOT NULL
                GROUP BY u.tg_id
                ORDER BY group_time DESC
                LIMIT 1
            `)
        ]);

        // Package the results safely (handling nulls if the database is empty)
        const stats = {
            totalHours: totalTimeResult[0].platform_total_time ? Math.round(totalTimeResult[0].platform_total_time / 3600) : 0, // Converted to Hours
            totalPoints: totalPointsResult[0].platform_total_points || 0,
            topGroup: topGroupResult.length > 0 ? `Group ${topGroupResult[0].tg_id}` : 'None Yet'
        };

        res.status(200).json({ success: true, data: stats });

    } catch (err) {
        console.error("Admin System Analytics Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// ==========================================
// 4. STORE INVENTORY MANAGEMENT
// ==========================================

// Add a new item to the store
exports.addStoreItem = async (req, res) => {
    const { name, description, cost, icon } = req.body;
    try {
        const sql = "INSERT INTO Store_Items (name, description, cost, icon) VALUES (?, ?, ?, ?)";
        await db.query(sql, [name, description, cost, icon]);
        res.status(201).json({ success: true, message: "Reward added to the store!" });
    } catch (err) {
        console.error("Add Item Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// Update the price of an item (Dynamic Pricing)
exports.updateItemPrice = async (req, res) => {
    const { item_id } = req.params;
    const { new_cost } = req.body;
    try {
        const sql = "UPDATE Store_Items SET cost = ? WHERE item_id = ?";
        await db.query(sql, [new_cost, item_id]);
        res.status(200).json({ success: true, message: "Price updated successfully!" });
    } catch (err) {
        console.error("Update Price Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// ==========================================
// 5. TOPIC DICTIONARY MANAGEMENT
// ==========================================
exports.getTopics = async (req, res) => {
    try {
        const [topics] = await db.query("SELECT * FROM Study_Topics ORDER BY topic_id ASC");
        res.status(200).json({ success: true, data: topics });
    } catch (err) {
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

exports.addTopic = async (req, res) => {
    const { topic_name } = req.body;
    try {
        await db.query("INSERT INTO Study_Topics (topic_name) VALUES (?)", [topic_name]);
        res.status(201).json({ success: true, message: "Topic added successfully!" });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({ success: false, message: "This topic already exists." });
        }
        res.status(500).json({ success: false, message: "Database Error" });
    }
};
