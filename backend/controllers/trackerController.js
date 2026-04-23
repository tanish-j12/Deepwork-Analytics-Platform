const db = require('../config/db');

exports.logActivity = async (req, res) => {
    // 1. Grab the raw data sent by your Python tracker
    const { s_id, title, timestamp } = req.body;
    
    // We will store the Category Keyword ID here. Default is null.
    let ck_id = null;

    try {
        // =========================================================
        // STEP 1: The Keyword Lookup
        // =========================================================
        // We search the Category_Keywords table for a matching keyword.
        // If found, we extract the exact 'ck_id' that triggered the match.
        const findCategorySql = `
            SELECT ck_id 
            FROM Category_Keywords 
            WHERE ? LIKE CONCAT('%', keyword, '%') 
            LIMIT 1
        `;
        
        const [categoryResults] = await db.query(findCategorySql, [title]);
        
        if (categoryResults.length > 0) {
            ck_id = categoryResults[0].ck_id; // Grab the Granular Keyword ID!
        }

        // =========================================================
        // STEP 2: The SQL Insert
        // =========================================================
        // We insert the log using the ck_id we just found.
        const insertSql = `
            INSERT INTO Activity_Logs (s_id, ck_id, window_title, timestamp, duration) 
            VALUES (?, ?, ?, ?, 5)
        `;
        
        await db.query(insertSql, [s_id, ck_id, title, timestamp]);
        res.status(200).json({ success: true, message: "Activity successfully categorized and logged." });
        
    } catch (err) {
        console.error("Tracker Database Error:", err.message);
        res.status(500).json({ success: false, message: "Database error" });
    }
};