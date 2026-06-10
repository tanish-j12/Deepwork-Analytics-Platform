const db = require('../config/db');

// ==========================================
// 1. KRYPTONITE PIE CHART (Top Distractions)
// ==========================================
exports.getKryptoniteStats = async (req, res) => {
    const { u_id } = req.params;

    try {
        const sql = `
            SELECT 
                ck.keyword AS app_name, 
                SUM(al.duration) AS total_seconds
            FROM Activity_Logs al
            JOIN Category_Keywords ck ON al.ck_id = ck.ck_id
            JOIN Website_Categories wc ON ck.wc_id = wc.wc_id
            JOIN Sessions s ON al.s_id = s.s_id
            WHERE s.u_id = ? AND LOWER(wc.category_type) = 'distracting'
            GROUP BY ck.keyword
            ORDER BY total_seconds DESC
            LIMIT 5;
        `;
        
        const [results] = await db.query(sql, [u_id]);
        res.status(200).json({ success: true, data: results });

    } catch (err) {
        console.error("Kryptonite Analytics Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// ==========================================
// 2. DASHBOARD QUICK STATS & TREND GRAPH
// ==========================================
exports.getDashboardStats = async (req, res) => {
    const { u_id } = req.params;

    try {
        // We use Promise.all to run all 5 queries at the exact same time for maximum speed
        const [
            [topSubjectResult], 
            [peakStudyResult], 
            [peakDistractResult], 
            [sevenDayTotalResult], 
            [trendResult]
        ] = await Promise.all([
            // Query 1: Most Focused Subject (UPDATED WITH INNER JOIN!)
            db.query(`
                SELECT st.topic_name, SUM(s.productive_time) as total_time 
                FROM Sessions s
                JOIN Study_Topics st ON s.topic_id = st.topic_id
                WHERE s.u_id = ? 
                GROUP BY st.topic_id 
                ORDER BY total_time DESC 
                LIMIT 1
            `, [u_id]),
            
            // Query 2: Peak Study Hour
            db.query(`SELECT HOUR(start_time) as hour, SUM(productive_time) as total_time FROM Sessions WHERE u_id = ? GROUP BY HOUR(start_time) ORDER BY total_time DESC LIMIT 1`, [u_id]),
            
            // Query 3: Peak Distraction Hour
            db.query(`SELECT HOUR(start_time) as hour, SUM(distraction_time) as total_time FROM Sessions WHERE u_id = ? GROUP BY HOUR(start_time) ORDER BY total_time DESC LIMIT 1`, [u_id]),
            
            // Query 4: Total Deep Work (Last 7 Days)
            db.query(`SELECT SUM(productive_time) as total_7d FROM Sessions WHERE u_id = ? AND start_time >= DATE_SUB(NOW(), INTERVAL 7 DAY)`, [u_id]),
            
            // Query 5: 7-Day Trend Graph Data
            db.query(`SELECT DATE(start_time) as study_date, SUM(productive_time) as daily_total FROM Sessions WHERE u_id = ? AND start_time >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY DATE(start_time) ORDER BY study_date ASC`, [u_id])
        ]);

        // Helper function to convert 24hr format to AM/PM (e.g., 14 -> 2 PM)
        const formatHour = (hour) => {
            if (hour === null || hour === undefined) return "N/A";
            const ampm = hour >= 12 ? 'PM' : 'AM';
            let formattedHour = hour % 12;
            formattedHour = formattedHour ? formattedHour : 12; 
            return `${formattedHour} ${ampm}`;
        };

        // Package all the data perfectly for the frontend
        const dashboardData = {
            // UPDATED: Now it pulls the topic_name directly from the database JOIN!
            topSubject: topSubjectResult.length > 0 ? topSubjectResult[0].topic_name : "N/A",
            
            peakStudyHour: peakStudyResult.length > 0 ? formatHour(peakStudyResult[0].hour) : "N/A",
            peakDistractHour: peakDistractResult.length > 0 ? formatHour(peakDistractResult[0].hour) : "N/A",
            totalDeepWork: sevenDayTotalResult[0].total_7d ? Math.round(sevenDayTotalResult[0].total_7d / 60) : 0, // Convert to minutes
            trendData: trendResult // Array of dates and times
        };

        res.status(200).json({ success: true, data: dashboardData });

    } catch (err) {
        console.error("Dashboard Analytics Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};
