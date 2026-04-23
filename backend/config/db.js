const mysql = require('mysql2');
require('dotenv').config();

// We use a "Pool" instead of a single connection because it handles multiple concurrent users efficiently
const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '@Tanish2005', // Your MySQL password
    database: 'DeepWorkAnalytics',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Export the pool wrapped in Promises so we can use async/await
module.exports = pool.promise();