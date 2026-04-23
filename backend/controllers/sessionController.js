const db = require('../config/db');

exports.startSession = async (req, res) => {
    const { u_id, topic_id, goal } = req.body;
    try {
        const sql = "INSERT INTO Sessions (u_id, topic_id, start_time, goal, status, final_score) VALUES (?, ?, NOW(), ?, 'active', 100)";
        const [result] = await db.query(sql, [u_id, topic_id, goal]);
        res.status(201).json({ success: true, s_id: result.insertId });
    } catch (err) {
        console.error("Start Session Error:", err);
        res.status(500).json({ success: false, message: "Server Error: " + err.message });
    }
};

exports.endSession = async (req, res) => {
    const { s_id } = req.body;
    try {
        const sql = "UPDATE Sessions SET status = 'completed', end_time = NOW() WHERE s_id = ?";
        await db.query(sql, [s_id]);
        res.status(200).json({ success: true, message: "Session Ended" });
    } catch (err) {
        console.error("End Session Error:", err);
        res.status(500).json({ success: false, message: "Server Error" });
    }
};

exports.getSessionStats = async (req, res) => {
    const { s_id } = req.params;
    try {
        const sql = `
            SELECT s.final_score, s.productive_time, s.distraction_time, u.total_bonus_points 
            FROM Sessions s JOIN Users u ON s.u_id = u.u_id 
            WHERE s.s_id = ?`;
        const [results] = await db.query(sql, [s_id]);
        res.status(200).json(results[0] || {});
    } catch (err) {
        console.error("Fetch Stats Error:", err);
        res.status(500).json({ success: false, message: "Server Error" });
    }
};

exports.getActiveSession = async (req, res) => {
    const { u_id } = req.params;
    try {
        const sql = "SELECT s_id FROM Sessions WHERE u_id = ? AND status = 'active' ORDER BY start_time DESC LIMIT 1";
        const [results] = await db.query(sql, [u_id]);
        res.status(200).json(results.length > 0 ? results[0] : { s_id: null });
    } catch (err) {
        console.error("Active Session Error:", err);
        res.status(500).json({ success: false, message: "Server Error" });
    }
};
