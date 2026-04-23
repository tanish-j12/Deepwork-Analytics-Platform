const db = require('../config/db');

// 1. Get the Top 10 Global Leaderboard
exports.getGlobalLeaderboard = async (req, res) => {
    try {
        const sql = `
            SELECT u_id, name, total_bonus_points 
            FROM Users 
            WHERE role = 'Student' 
            ORDER BY total_bonus_points DESC 
            LIMIT 10
        `;
        const [results] = await db.query(sql);
        res.status(200).json({ success: true, leaderboard: results });
    } catch (err) {
        console.error("Global Leaderboard Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// 2. Get the Top 10 for a Specific Tutorial Group
exports.getGroupLeaderboard = async (req, res) => {
    const { tg_id } = req.params;
    try {
        // SQL Flex: Joining Users with Tutorial_Groups to verify the group data
        const sql = `
            SELECT u.u_id, u.name, u.total_bonus_points, tg.tg_number 
            FROM Users u
            JOIN Tutorial_Groups tg ON u.tg_id = tg.tg_id
            WHERE u.tg_id = ? AND u.role = 'Student'
            ORDER BY u.total_bonus_points DESC 
            LIMIT 10
        `;
        const [results] = await db.query(sql, [tg_id]);
        res.status(200).json({ success: true, leaderboard: results });
    } catch (err) {
        console.error("Group Leaderboard Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};