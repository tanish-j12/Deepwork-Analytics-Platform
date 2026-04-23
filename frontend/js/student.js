// ==========================================
// 1. AUTHENTICATION & SETUP
// ==========================================
const userString = localStorage.getItem('deepwork_user');

if (!userString) {
    window.location.href = 'login.html';
}

const currentUser = JSON.parse(userString);

document.getElementById('nav-name').innerText = currentUser.name;
document.getElementById('dash-name').innerText = currentUser.name.split(' ')[0];
document.getElementById('nav-points').innerText = currentUser.total_bonus_points;

// ==========================================
// 1.THE INVENTORY ENGINE (Applies Rewards)
// ==========================================
async function applyUserRewards() {
    try {
        const res = await fetch(`http://localhost:3000/api/store/inventory/${currentUser.u_id}`);
        const data = await res.json();

        if (data.success) {
            const ownedItems = data.inventory;

            // 🌟 FLEX 1: The "Night Owl" Theme
            if (ownedItems.includes('"Night Owl" Theme')) {
                // Change the background to pure black and borders to neon purple
                document.body.classList.remove('bg-gray-900');
                document.body.classList.add('bg-black');
                
                // Add a cool neon glow to the navbar
                document.querySelector('nav').classList.add('border-purple-500', 'shadow-[0_0_15px_rgba(168,85,247,0.5)]');
            }

            // 🌟 FLEX 2: Custom Profile Badges
            if (ownedItems.includes('Custom Profile Badges')) {
                // Find the badge in the full data to get the icon
                const badgeData = data.fullData.find(item => item.name === 'Custom Profile Badges');
                
                // Inject the badge next to their name in the Navbar
                document.getElementById('nav-name').innerHTML = `${currentUser.name} <span class="text-xl ml-1" title="Algorithm Ace">${badgeData.icon}</span>`;
            }
            
            // 🌟 FLEX 3: Golden Username
            if (ownedItems.includes('Golden Username')) {
                // Make their name gold in the dashboard greeting
                const dashName = document.getElementById('dash-name');
                dashName.classList.remove('text-white');
                dashName.classList.add('text-yellow-400', 'drop-shadow-[0_0_8px_rgba(250,204,21,0.8)]');
            }
        }
    } catch (err) {
        console.error("Failed to load inventory:", err);
    }
}

// Call the function immediately when the page loads!
applyUserRewards();

// ==========================================
// 2. VIEW MANAGEMENT (TABS)
// ==========================================
function switchTab(tab) {
    document.getElementById('view-dashboard').classList.add('hidden');
    document.getElementById('view-store').classList.add('hidden');
    document.getElementById('view-leaderboard').classList.add('hidden');
    document.getElementById('view-analytics').classList.add('hidden'); // NEW
    
    document.getElementById(`view-${tab}`).classList.remove('hidden');

    if (tab === 'leaderboard') loadLeaderboard('global');
    if (tab === 'store') loadStore();
    if (tab === 'analytics') loadAnalyticsDashboard(); // NEW
}

function logout() {
    localStorage.removeItem('deepwork_user');
    window.location.href = 'login.html';
}

// ==========================================
// 3. SESSION ENGINE
// ==========================================
let sessionId = null;
let pollInterval = null;

document.getElementById('btn-start').addEventListener('click', async () => {
    const selectedTopicId = document.getElementById('topic-select').value;
    let sessionGoal = document.getElementById('session-goal').value.trim();
    if (sessionGoal === "") sessionGoal = "General Study Session";
    
    try {
        const res = await fetch('http://localhost:3000/api/sessions/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                u_id: currentUser.u_id, 
                topic_id: parseInt(selectedTopicId), 
                goal: sessionGoal 
            })
        });
        
        const data = await res.json();
        
        if (data.success) {
            sessionId = data.s_id;
            document.getElementById('stat-id').innerText = '#' + sessionId;
            
            document.getElementById('btn-start').classList.add('hidden');
            document.getElementById('topic-select').disabled = true; 
            document.getElementById('session-goal').disabled = true; 
            document.getElementById('btn-end').classList.remove('hidden');
            document.getElementById('sync-dot').classList.replace('bg-red-500', 'bg-green-500');
            
            pollInterval = setInterval(fetchStats, 2000);
        } else {
            alert("Database Error: " + data.message);
        }
    } catch (err) {
        alert("Server connection failed. Is Node.js running?");
    }
});

document.getElementById('btn-end').addEventListener('click', async () => {
    try {
        const res = await fetch('http://localhost:3000/api/sessions/end', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ s_id: sessionId })
        });
        
        if (res.ok) {
            clearInterval(pollInterval);
            await fetchStats(); 
            
            document.getElementById('btn-start').classList.remove('hidden');
            document.getElementById('topic-select').disabled = false; 
            document.getElementById('session-goal').disabled = false; 
            document.getElementById('session-goal').value = ""; 
            document.getElementById('btn-end').classList.add('hidden');
            document.getElementById('sync-dot').classList.replace('bg-green-500', 'bg-red-500');
            
            sessionId = null;
            alert("Session Ended Successfully! Final scores calculated.");
        }
    } catch (err) {
        alert("Error ending session.");
    }
});

async function fetchStats() {
    if (!sessionId) return;
    try {
        const res = await fetch(`http://localhost:3000/api/sessions/stats/${sessionId}`);
        const stats = await res.json();
        
        if (stats.final_score !== undefined) {
            document.getElementById('stat-score').innerText = stats.final_score;
            document.getElementById('stat-prod').innerText = stats.productive_time + 's';
            document.getElementById('stat-dist').innerText = stats.distraction_time + 's';
            
            if (stats.total_bonus_points !== undefined && stats.total_bonus_points !== currentUser.total_bonus_points) {
                currentUser.total_bonus_points = stats.total_bonus_points;
                document.getElementById('nav-points').innerText = stats.total_bonus_points;
                localStorage.setItem('deepwork_user', JSON.stringify(currentUser));
            }
        }
    } catch (err) {
        console.error("Failed to fetch live stats", err);
    }
}

// ==========================================
// 4. LEADERBOARD ENGINE
// ==========================================
const btnGlobal = document.getElementById('btn-global-board');
const btnGroup = document.getElementById('btn-group-board');
const leaderboardBody = document.getElementById('leaderboard-body');

async function loadLeaderboard(type) {
    if (type === 'global') {
        btnGlobal.className = "bg-blue-600 px-4 py-2 rounded text-white font-bold transition shadow";
        btnGroup.className = "bg-transparent hover:bg-gray-700 px-4 py-2 rounded text-gray-400 font-bold transition";
    } else {
        btnGroup.className = "bg-blue-600 px-4 py-2 rounded text-white font-bold transition shadow";
        btnGlobal.className = "bg-transparent hover:bg-gray-700 px-4 py-2 rounded text-gray-400 font-bold transition";
    }

    leaderboardBody.innerHTML = `<tr><td colspan="3" class="p-8 text-center text-gray-400 animate-pulse">Fetching latest rankings...</td></tr>`;

    try {
        const userGroupId = currentUser.tg_id || 1; 
        const url = type === 'global' ? 'http://localhost:3000/api/leaderboard/global' : `http://localhost:3000/api/leaderboard/group/${userGroupId}`;
        const res = await fetch(url);
        const data = await res.json();

        if (data.success && data.leaderboard.length > 0) {
            leaderboardBody.innerHTML = ''; 
            data.leaderboard.forEach((student, index) => {
                let rankDisplay = index + 1;
                if (rankDisplay === 1) rankDisplay = '<span class="text-2xl">🥇</span> 1st';
                else if (rankDisplay === 2) rankDisplay = '<span class="text-xl">🥈</span> 2nd';
                else if (rankDisplay === 3) rankDisplay = '<span class="text-lg">🥉</span> 3rd';
                else rankDisplay = `<span class="text-gray-500 font-bold">#${rankDisplay}</span>`;

                const isMe = student.u_id === currentUser.u_id;
                const rowClass = isMe ? "bg-blue-900 bg-opacity-30 border-l-4 border-blue-500" : "hover:bg-gray-700 transition";
                const nameDisplay = isMe ? `<span class="font-bold text-white">${student.name} (You)</span>` : student.name;

                leaderboardBody.innerHTML += `
                    <tr class="${rowClass}">
                        <td class="p-4">${rankDisplay}</td>
                        <td class="p-4 text-gray-300">${nameDisplay}</td>
                        <td class="p-4 text-right text-green-400 font-mono text-lg font-bold">${student.total_bonus_points}</td>
                    </tr>
                `;
            });
        } else {
            leaderboardBody.innerHTML = `<tr><td colspan="3" class="p-8 text-center text-gray-400">No data available yet.</td></tr>`;
        }
    } catch (err) {
        leaderboardBody.innerHTML = `<tr><td colspan="3" class="p-8 text-center text-red-400 font-bold">Failed to connect to the ranking server.</td></tr>`;
    }
}

btnGlobal.addEventListener('click', () => loadLeaderboard('global'));
btnGroup.addEventListener('click', () => loadLeaderboard('group'));

// ==========================================
// 5. REWARDS STORE ENGINE
// ==========================================
const storeGrid = document.getElementById('store-grid');
const storeWallet = document.getElementById('store-wallet');

async function loadStore() {
    storeWallet.innerText = currentUser.total_bonus_points; 
    
    try {
        const res = await fetch('http://localhost:3000/api/store/items');
        const data = await res.json();

        if (data.success) {
            storeGrid.innerHTML = ''; 
            
            data.items.forEach(item => {
                const canAfford = currentUser.total_bonus_points >= item.cost;
                const btnColor = canAfford ? 'bg-blue-600 hover:bg-blue-500' : 'bg-gray-600 cursor-not-allowed opacity-50';
                
                // THE FIX: Safely escape quotes so the HTML button doesn't break!
                const safeName = item.name.replace(/"/g, '&quot;').replace(/'/g, "\\'");
                
                storeGrid.innerHTML += `
                    <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-lg flex flex-col justify-between hover:border-blue-500 transition">
                        <div>
                            <div class="text-4xl mb-4">${item.icon}</div>
                            <h3 class="text-xl font-bold text-white mb-2">${item.name}</h3>
                            <p class="text-sm text-gray-400 mb-4 h-12">${item.description}</p>
                        </div>
                        <button 
                            onclick="buyItem(${item.item_id}, ${item.cost}, '${safeName}')" 
                            class="w-full py-2 rounded font-bold text-white transition shadow ${btnColor}"
                            ${!canAfford ? 'disabled' : ''}>
                            ${item.cost} pts
                        </button>
                    </div>
                `;
            });
        }
    } catch (err) {
        console.error("Store Error:", err);
    }
}

window.buyItem = async function(itemId, cost, itemName) {
    if (confirm(`Are you sure you want to buy "${itemName}" for ${cost} pts?`)) {
        try {
            const res = await fetch('http://localhost:3000/api/store/buy', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ u_id: currentUser.u_id, item_id: itemId, cost: cost })
            });
            
            const data = await res.json();
            
            if (data.success) {
                alert(`Success! You bought ${itemName}.`);
                currentUser.total_bonus_points = data.new_balance;
                localStorage.setItem('deepwork_user', JSON.stringify(currentUser));
                document.getElementById('nav-points').innerText = data.new_balance;
                document.getElementById('store-wallet').innerText = data.new_balance;
                loadStore(); // Reload store to update buttons
                applyUserRewards(); // <-- ADD THIS: Instantly apply the new reward! 
            } else {
                alert(data.message);
            }
        } catch (err) {
            alert("Transaction failed to connect to server.");
        }
    }
};

// ==========================================
// TASK 6: DB CONFLICT SIMULATION
// ==========================================
window.simulateConflict = async function() {
    // 1. We are going to try and buy the "Night Owl Theme" (Item ID: 2, Cost: 500)
    const itemId = 2;
    const cost = 500;

    // Check if we even have 500 points to start with for the test
    if (currentUser.total_bonus_points < cost) {
        alert("You need at least 500 points to run this test! Update your points in MySQL first.");
        return;
    }

    alert("Firing 2 identical purchase requests at the exact same millisecond...");

    const requestBody = {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ u_id: currentUser.u_id, item_id: itemId, cost: cost })
    };

    try {
        // Fire BOTH requests at the exact same time
        const [response1, response2] = await Promise.all([
            fetch('http://localhost:3000/api/store/buy', requestBody),
            fetch('http://localhost:3000/api/store/buy', requestBody)
        ]);

        const result1 = await response1.json();
        const result2 = await response2.json();

        // Log the results to show the professor
        console.log("Transaction 1 Result:", result1);
        console.log("Transaction 2 Result:", result2);

        alert(`
            Test Complete! Look at your browser console (F12).
            Transaction 1: ${result1.message}
            Transaction 2: ${result2.message}
        `);

        // Refresh the UI to show the final balance
        if (result1.success) currentUser.total_bonus_points = result1.new_balance;
        localStorage.setItem('deepwork_user', JSON.stringify(currentUser));
        document.getElementById('nav-points').innerText = currentUser.total_bonus_points;
        loadStore();

    } catch (err) {
        console.error("Simulation failed:", err);
    }
};
// ==========================================
// 7. ANALYTICS & CHART ENGINE
// ==========================================
let kryptoniteChartInstance = null; 
let trendChartInstance = null;

async function loadAnalyticsDashboard() {
    try {
        // --- 1. FETCH DASHBOARD STATS & TRENDS ---
        const dashRes = await fetch(`http://localhost:3000/api/analytics/dashboard/${currentUser.u_id}`);
        const dashData = await dashRes.json();

        if (dashData.success) {
            const stats = dashData.data;

            // Update Quick Stats UI
            document.getElementById('stat-top-subject').innerText = stats.topSubject;
            document.getElementById('stat-top-subject').classList.remove('animate-pulse');

            document.getElementById('stat-peak-study').innerText = stats.peakStudyHour;
            document.getElementById('stat-peak-study').classList.remove('animate-pulse');

            document.getElementById('stat-peak-distract').innerText = stats.peakDistractHour;
            document.getElementById('stat-peak-distract').classList.remove('animate-pulse');

            document.getElementById('stat-total-deepwork').innerText = `${stats.totalDeepWork} mins`;
            document.getElementById('stat-total-deepwork').classList.remove('animate-pulse');

            // Draw 7-Day Trend Line Chart
            const trendCtx = document.getElementById('chart-trend').getContext('2d');
            if (trendChartInstance) trendChartInstance.destroy();

            // Map the SQL dates and minutes for the graph
            const labels = stats.trendData.map(row => new Date(row.study_date).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }));
            const dataPoints = stats.trendData.map(row => Math.round(row.daily_total / 60)); // Minutes

            trendChartInstance = new Chart(trendCtx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Focus Minutes',
                        data: dataPoints,
                        borderColor: '#60a5fa', // Tailwind blue-400
                        backgroundColor: 'rgba(96, 165, 250, 0.2)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4 // Makes the line smoothly curved
                    }]
                },
                options: {
                    responsive: true,
                    scales: {
                        y: { beginAtZero: true, grid: { color: '#374151' }, ticks: { color: '#9ca3af' } },
                        x: { grid: { display: false }, ticks: { color: '#9ca3af' } }
                    },
                    plugins: { legend: { display: false } }
                }
            });
        }

        // --- 2. FETCH KRYPTONITE PIE CHART ---
        const krypRes = await fetch(`http://localhost:3000/api/analytics/kryptonite/${currentUser.u_id}`);
        const krypData = await krypRes.json();

        if (krypData.success && krypData.data.length > 0) {
            const labels = krypData.data.map(row => row.app_name.toUpperCase());
            const times = krypData.data.map(row => Math.round(row.total_seconds / 60)); 

            const krypCtx = document.getElementById('chart-kryptonite').getContext('2d');
            if (kryptoniteChartInstance) kryptoniteChartInstance.destroy();

            kryptoniteChartInstance = new Chart(krypCtx, {
                type: 'doughnut',
                data: {
                    labels: labels,
                    datasets: [{
                        data: times,
                        backgroundColor: [
                            'rgba(239, 68, 68, 0.8)', 'rgba(245, 158, 11, 0.8)', 
                            'rgba(59, 130, 246, 0.8)', 'rgba(168, 85, 247, 0.8)', 'rgba(107, 114, 128, 0.8)'
                        ],
                        borderColor: '#1f2937', 
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: { position: 'bottom', labels: { color: '#9ca3af' } }
                    }
                }
            });
        }
    } catch (err) {
        console.error("Analytics Dashboard Error:", err);
    }
}