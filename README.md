# DeepWork Analytics 🧠⚡

DeepWork Analytics is a full-stack, gamified productivity ecosystem. Instead of relying on traditional honor-system timers, it utilizes a background Python daemon to cryptographically verify a user's focus state, logging productive time and converting it into a virtual economy. 

This project was architected to handle high concurrency, featuring an enterprise-grade relational database, Role-Based Access Control (RBAC), and strict ACID-compliant transactions.

## 🚀 Key Features

* **Automated Focus Tracking:** A Python daemon utilizes OS-level hooks to silently monitor active foreground windows, pinging the backend via a REST API to classify activity as "Productive" or "Distracting."
* **Gamified Virtual Economy:** Students earn focus points for verified deep work, which they can spend in a digital Rewards Store.
* **Concurrency Control:** The Rewards Store is secured using Row-Level Locking (`SELECT ... FOR UPDATE`) inside an ACID-compliant MySQL transaction to completely eliminate Double-Spend race conditions.
* **Role-Based Access Control (RBAC):** Features a distinct "Admin Command Center" for secure user provisioning, dynamic price updating, and Master Data Management (MDM) of the official study dictionary.
* **Real-Time Analytics Command Center:** Short-polling client synchronization combined with concurrent backend SQL aggregations (`Promise.all()`) drives a dynamic, real-time Chart.js dashboard.

## 💻 Tech Stack

**Frontend:**
* HTML5, Vanilla JavaScript
* Tailwind CSS (Rapid UI styling)
* Chart.js (Data visualization)

**Backend & Architecture:**
* Node.js & Express.js (REST API Gateway)
* Python 3 (Daemon tracking process)
* **Database:** MySQL (InnoDB Engine)
* **Optimization:** `mysql2` Connection Pooling, B-Tree Indexing

---

## 🛠️ Installation & Local Setup

### 1. Prerequisites
Ensure you have the following installed on your machine:
* [Node.js](https://nodejs.org/) (v16+)
* [Python](https://www.python.org/) (v3.8+)
* [MySQL Server](https://dev.mysql.com/downloads/)

### 2. Database Initialization
1. Open MySQL Workbench (or your preferred SQL CLI).
2. Create the database: `CREATE DATABASE deepwork;`
3. Execute the SQL scripts (e.g., `schema.sql`) to generate the Normalized (3NF) tables.

### 3. Backend & Database Configuration
1. Open your terminal and navigate to the backend directory:
   ```bash
   cd backend
Install the Node dependencies:

Bash
npm install express cors mysql2 dotenv
Configure the Database Connection: Navigate to the config folder and open db.js (or your .env file if you are using environment variables). Update the connection pool settings with your local MySQL credentials:

JavaScript
// Inside backend/config/db.js
const pool = mysql.createPool({
    host: 'localhost',
    user: 'root', // Replace with your MySQL username
    password: 'your_password', // Replace with your MySQL password
    database: 'deepwork',
    connectionLimit: 10
});
Start the Node.js API server:

Bash
node server.js
4. Python Tracker Setup
Open a new terminal instance and navigate to the tracker directory:

Bash
cd tracker
Install the required OS hooks and request libraries:

Bash
pip install pygetwindow requests
Run the tracking daemon:

Bash
python tracker.py
5. Frontend Setup
Because the frontend utilizes standard web technologies, simply open frontend/login.html in your web browser (or use the VS Code Live Server extension) to boot up the application.

🗄️ Relational Database Architecture
The MySQL database is strictly normalized and separated into three distinct domains:

Master Data & Users: Users and Study_Topics tables handle RBAC and system-wide dropdown population.

Session Engine: Sessions, Activity_Logs, and Category_Keywords handle the One-to-Many ingestion of high-frequency Python tracker data.

Virtual Economy: Store_Items and Purchases utilize a Many-to-Many junction structure to enforce transactional integrity during reward checkouts.

🤝 Author
Tanish Jindal | Computer Science & Applied Mathematics (CSAM) Undergraduate

Built to demonstrate system architecture, concurrency handling, and full-stack API design.
