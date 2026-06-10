// ==========================================
// 1. SECURITY BOUNCER & SETUP
// ==========================================
const userString = localStorage.getItem('deepwork_user');

if (!userString) {
    window.location.href = 'login.html';
}

const currentUser = JSON.parse(userString);

// CRITICAL RBAC CHECK: Kick out non-admins!
if (currentUser.role !== 'Admin') {
    alert("SECURITY BREACH: Unauthorized Access. Your attempt has been logged.");
    window.location.href = 'login.html';
}

document.getElementById('admin-name').innerText = currentUser.name;

// ==========================================
// 2. VIEW MANAGEMENT (TABS)
// ==========================================
function switchTab(tab) {
    document.getElementById('view-stats').classList.add('hidden');
    document.getElementById('view-users').classList.add('hidden');
    document.getElementById('view-store').classList.add('hidden');
    document.getElementById('view-topics').classList.add('hidden'); // Hide it by default
    document.getElementById(`view-${tab}`).classList.remove('hidden');

    // Trigger data loads
    if (tab === 'stats') loadSystemStats(); // <--- This now calls your new function!
    if (tab === 'users') loadUsers(); 
    if (tab === 'store') loadAdminStore();
    if (tab === 'topics') loadTopics(); // Trigger the fetch
}

// Optional: Call loadSystemStats() right at the top of your file so it loads automatically when the page first opens!
loadSystemStats();

function logout() {
    localStorage.removeItem('deepwork_user');
    window.location.href = 'login.html';
}

// ==========================================
// 3. USER MANAGEMENT ENGINE (CRUD)
// ==========================================
const userTableBody = document.getElementById('user-table-body');

// Toggle the form visibility
function toggleUserForm() {
    const form = document.getElementById('add-user-form');
    form.classList.toggle('hidden');
}

// Fetch and display all users
async function loadUsers() {
    userTableBody.innerHTML = `<tr><td colspan="5" class="p-4 text-center text-gray-400 animate-pulse">Querying database...</td></tr>`;
    
    try {
        const res = await fetch('http://localhost:3000/api/admin/users');
        const result = await res.json();

        if (result.success) {
            userTableBody.innerHTML = ''; // Clear loading text
            
            result.data.forEach(user => {
                // Add a cool badge for Admins
                const roleBadge = user.role === 'Admin' 
                    ? `<span class="bg-red-900 text-red-300 text-xs px-2 py-1 ml-2 rounded border border-red-700">Admin</span>` 
                    : '';

                userTableBody.innerHTML += `
                    <tr class="hover:bg-gray-700 transition">
                        <td class="p-4 text-gray-400 font-mono">#${user.u_id}</td>
                        <td class="p-4 font-bold text-white flex items-center">${user.name} ${roleBadge}</td>
                        <td class="p-4 text-gray-300">${user.email}</td>
                        <td class="p-4 text-gray-300">TG-${user.tg_id || 'None'}</td>
                        <td class="p-4 text-yellow-400 font-bold">${user.total_bonus_points}</td>
                    </tr>
                `;
            });
        }
    } catch (err) {
        userTableBody.innerHTML = `<tr><td colspan="5" class="p-4 text-center text-red-400">Failed to load user database.</td></tr>`;
    }
}

// Handle the "Create User" form submission
document.getElementById('create-user-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const name = document.getElementById('new-name').value;
    const email = document.getElementById('new-email').value;
    const tg_id = document.getElementById('new-tg').value;
    const password = document.getElementById('new-pass').value;

    try {
        const res = await fetch('http://localhost:3000/api/admin/users', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, tg_id, password })
        });
        
        const data = await res.json();

        if (data.success) {
            alert("✅ " + data.message);
            document.getElementById('create-user-form').reset(); // Clear inputs
            toggleUserForm(); // Hide form
            loadUsers(); // Instantly refresh the table to show the new user!
        } else {
            alert("❌ " + data.message);
        }
    } catch (err) {
        alert("Server connection failed.");
    }
});

// ==========================================
// 4. SYSTEM ANALYTICS ENGINE
// ==========================================
async function loadSystemStats() {
    try {
        const res = await fetch('http://localhost:3000/api/admin/stats');
        const result = await res.json();

        if (result.success) {
            // Stop the pulsing animation and inject the data
            const timeEl = document.getElementById('sys-total-time');
            timeEl.innerText = `${result.data.totalHours} hrs`;
            timeEl.classList.remove('animate-pulse');

            const pointsEl = document.getElementById('sys-total-points');
            pointsEl.innerText = result.data.totalPoints;
            pointsEl.classList.remove('animate-pulse');

            const groupEl = document.getElementById('sys-top-group');
            groupEl.innerText = result.data.topGroup;
            groupEl.classList.remove('animate-pulse');
        }
    } catch (err) {
        console.error("Failed to load system stats:", err);
        document.getElementById('sys-total-time').innerText = "ERROR";
    }
}

// ==========================================
// 5. STORE INVENTORY ENGINE
// ==========================================
const adminStoreGrid = document.getElementById('admin-store-grid');

function toggleStoreForm() {
    document.getElementById('add-store-form').classList.toggle('hidden');
}

// Load current inventory
async function loadAdminStore() {
    adminStoreGrid.innerHTML = '<div class="text-gray-400 animate-pulse col-span-full text-center p-8">Fetching database records...</div>';
    
    try {
        // We can reuse the student endpoint to fetch the items!
        const res = await fetch('http://localhost:3000/api/store/items');
        const data = await res.json();

        if (data.success) {
            adminStoreGrid.innerHTML = ''; 
            
            data.items.forEach(item => {
                // Notice the "Update Price" button!
                adminStoreGrid.innerHTML += `
                    <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-lg flex flex-col justify-between">
                        <div>
                            <div class="text-4xl mb-4">${item.icon}</div>
                            <h3 class="text-xl font-bold text-white mb-2">${item.name} <span class="text-xs text-gray-500 font-mono ml-2">#${item.item_id}</span></h3>
                            <p class="text-sm text-gray-400 mb-4 h-12">${item.description}</p>
                        </div>
                        <div class="flex justify-between items-center border-t border-gray-700 pt-4 mt-2">
                            <span class="text-yellow-400 font-bold">${item.cost} pts</span>
                            <button onclick="updatePrice(${item.item_id}, '${item.name.replace(/'/g, "\\'")}')" class="text-sm bg-gray-700 hover:bg-gray-600 px-3 py-1 rounded transition text-white">
                                Edit Price
                            </button>
                        </div>
                    </div>
                `;
            });
        }
    } catch (err) {
        adminStoreGrid.innerHTML = '<div class="text-red-400 col-span-full text-center">Failed to connect to database.</div>';
    }
}

// Handle adding a new item
document.getElementById('create-item-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const name = document.getElementById('new-item-name').value;
    const description = document.getElementById('new-item-desc').value;
    const cost = document.getElementById('new-item-cost').value;
    const icon = document.getElementById('new-item-icon').value;

    try {
        const res = await fetch('http://localhost:3000/api/admin/store', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, description, cost, icon })
        });
        
        const data = await res.json();

        if (data.success) {
            alert("✅ " + data.message);
            document.getElementById('create-item-form').reset();
            toggleStoreForm();
            loadAdminStore(); // Refresh grid instantly
        } else {
            alert("❌ " + data.message);
        }
    } catch (err) {
        alert("Server connection failed.");
    }
});

// Handle updating a price
window.updatePrice = async function(itemId, itemName) {
    const newPrice = prompt(`Enter the new price for "${itemName}":`);
    
    // Validate input is a positive number
    if (!newPrice || isNaN(newPrice) || parseInt(newPrice) <= 0) return;

    try {
        const res = await fetch(`http://localhost:3000/api/admin/store/${itemId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ new_cost: parseInt(newPrice) })
        });
        
        const data = await res.json();
        if (data.success) {
            loadAdminStore(); // Refresh grid to show new price
        } else {
            alert("❌ " + data.message);
        }
    } catch (err) {
        alert("Failed to update price.");
    }
};

// ==========================================
// 6. STUDY DICTIONARY ENGINE
// ==========================================
const topicTableBody = document.getElementById('topic-table-body');

async function loadTopics() {
    topicTableBody.innerHTML = `<tr><td colspan="2" class="p-4 text-center text-gray-400 animate-pulse">Loading subjects...</td></tr>`;
    
    try {
        const res = await fetch('http://localhost:3000/api/admin/topics');
        const result = await res.json();

        if (result.success) {
            topicTableBody.innerHTML = ''; 
            
            result.data.forEach(topic => {
                topicTableBody.innerHTML += `
                    <tr class="hover:bg-gray-700 transition">
                        <td class="p-4 text-emerald-400 font-mono font-bold">#${topic.topic_id}</td>
                        <td class="p-4 text-white">${topic.topic_name}</td>
                    </tr>
                `;
            });
        }
    } catch (err) {
        topicTableBody.innerHTML = `<tr><td colspan="2" class="p-4 text-center text-red-400">Database connection failed.</td></tr>`;
    }
}

document.getElementById('create-topic-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const topicName = document.getElementById('new-topic-name').value;

    try {
        const res = await fetch('http://localhost:3000/api/admin/topics', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ topic_name: topicName })
        });
        
        const data = await res.json();
        if (data.success) {
            document.getElementById('create-topic-form').reset();
            loadTopics(); // Instantly refresh the table
        } else {
            alert("❌ " + data.message);
        }
    } catch (err) {
        alert("Failed to add topic.");
    }
});
