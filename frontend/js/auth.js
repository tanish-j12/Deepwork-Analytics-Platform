document.getElementById('login-form').addEventListener('submit', async (e) => {
    // Prevent the form from refreshing the page
    e.preventDefault(); 

    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorMsg = document.getElementById('error-message');

    try {
        // 1. Send the POST request to our Node.js backend API
        const response = await fetch('http://localhost:3000/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });

        const data = await response.json();

        if (data.success) {
            // 2. Save the user data to the browser's local memory
            localStorage.setItem('deepwork_user', JSON.stringify(data.user));

            // --- 3. The IPC Bridge (Desktop Tracker Sync) ---
            // Silently ping the Python Desktop Tracker to wake it up!
            try {
                await fetch('http://localhost:5005/link-tracker', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ 
                        u_id: data.user.u_id, 
                        name: data.user.name 
                    })
                });
                console.log("Successfully linked to Desktop Tracker");
            } catch (err) {
                console.warn("Desktop tracker is not running locally. That's okay!");
            }
            // ------------------------------------------------

            // 4. Role-based routing: Send Admins to admin.html, Students to student.html
            if (data.user.role === 'Admin') {
                window.location.href = 'admin.html';
            } else {
                window.location.href = 'student.html';
            }
            
        } else {
            // Show the error message from the backend (e.g., "Invalid email")
            errorMsg.innerText = data.message;
            errorMsg.classList.remove('hidden');
        }
    } catch (err) {
        // If the Node.js server is turned off
        errorMsg.innerText = "Cannot connect to the server. Is the Node.js backend running?";
        errorMsg.classList.remove('hidden');
    }
});