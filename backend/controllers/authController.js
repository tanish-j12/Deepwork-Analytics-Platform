const db = require('../config/db');
const bcrypt = require('bcrypt'); // Industry standard for password hashing

exports.login = async (req, res) => {
    const { email, password } = req.body;

    try {
       // 1. Look up the user by email (Now including tg_id!)
const sql = "SELECT u_id, name, email, role, tg_id, total_bonus_points, password FROM Users WHERE email = ?";
        const [users] = await db.query(sql, [email]);

        // 2. If no user is found
        if (users.length === 0) {
            return res.status(401).json({ success: false, message: "Invalid email or password." });
        }

        const user = users[0];

        // 3. Check the password
        // Note for your resume: In a real app, we use bcrypt.compare(password, user.password)
        // For this local demo, we are doing a direct string match based on the SQL update we ran earlier.
        if (password !== user.password) {
             return res.status(401).json({ success: false, message: "Invalid email or password." });
        }

        // 4. Success! Remove the password from the object before sending it to the frontend
        delete user.password;

        res.status(200).json({ 
            success: true, 
            message: "Login successful", 
            user: user 
        });

    } catch (err) {
        console.error("[Login Error]:", err.message);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
};