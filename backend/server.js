const express = require('express');
const cors = require('cors');
require('dotenv').config();

// 1. Import ALL our isolated route files
const authRoutes = require('./routes/authRoutes');
const sessionRoutes = require('./routes/sessionRoutes'); // <-- NEW
const trackerRoutes = require('./routes/trackerRoutes'); // <-- NEW
const leaderboardRoutes = require('./routes/leaderboardRoutes');
const storeRoutes = require('./routes/storeRoutes');
const analyticsRoutes = require('./routes/analyticsRoutes');

const app = express();
const PORT = 3000;

// 2. Middleware
app.use(cors()); // Allows your frontend HTML to talk to this backend
app.use(express.json()); // Allows the server to read JSON payloads

// 3. API Routing Prefixing (The Receptionist Desk)
app.use('/api/auth', authRoutes);
app.use('/api/sessions', sessionRoutes); // <-- NEW
app.use('/api/tracker', trackerRoutes);  // <-- NEW
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/store', storeRoutes);
app.use('/api/analytics', analyticsRoutes);
// 4. Health Check
app.get('/api/health', (req, res) => {
    res.json({ success: true, message: 'DeepWork Analytics API is running securely! 🚀' });
});

app.listen(PORT, () => {
    console.log(`Server is live on http://localhost:${PORT}`);
});