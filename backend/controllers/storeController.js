const db = require('../config/db');

// Fetch all available items
exports.getStoreItems = async (req, res) => {
    try {
        const [items] = await db.query("SELECT * FROM Store_Items ORDER BY cost ASC");
        res.status(200).json({ success: true, items });
    } catch (err) {
        res.status(500).json({ success: false, message: "Database Error" });
    }
};

// The Purchase Transaction Engine
exports.purchaseItem = async (req, res) => {
    const { u_id, item_id, cost } = req.body;

    // Grab a dedicated connection for the transaction
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        // 1. Lock the user row and check their balance
        const [users] = await connection.query("SELECT total_bonus_points FROM Users WHERE u_id = ? FOR UPDATE", [u_id]);
        const currentPoints = users[0].total_bonus_points;

        if (currentPoints < cost) {
            await connection.rollback();
            return res.status(400).json({ success: false, message: "Not enough points!" });
        }

        // 2. Deduct the points
        const newPoints = currentPoints - cost;
        await connection.query("UPDATE Users SET total_bonus_points = ? WHERE u_id = ?", [newPoints, u_id]);

        // 3. Log the purchase
        await connection.query("INSERT INTO Purchases (u_id, item_id) VALUES (?, ?)", [u_id, item_id]);

        // 4. Save everything permanently
        await connection.commit();

        res.status(200).json({ success: true, message: "Purchase successful!", new_balance: newPoints });

    } catch (err) {
        await connection.rollback(); // Undo if anything breaks
        console.error("Transaction Error:", err);
        res.status(500).json({ success: false, message: "Transaction failed." });
    } finally {
        connection.release(); // Free up the database connection
    }
};

// Fetch a specific user's purchased items
exports.getUserInventory = async (req, res) => {
    const { u_id } = req.params;
    try {
        const sql = `
            SELECT si.name, si.icon 
            FROM Purchases p
            JOIN Store_Items si ON p.item_id = si.item_id
            WHERE p.u_id = ?
        `;
        const [inventory] = await db.query(sql, [u_id]);
        
        // Convert the array of objects into a simple array of item names for easy checking
        const ownedItems = inventory.map(item => item.name);
        
        res.status(200).json({ success: true, inventory: ownedItems, fullData: inventory });
    } catch (err) {
        console.error("Inventory Fetch Error:", err);
        res.status(500).json({ success: false, message: "Database Error" });
    }
};