# 🚀 NoteForge Backend (REST API + SQLite Database)

Integrated backend server and relational SQLite database built for the **NoteForge** Cross-Platform Application (CPAD).

---

## 📋 Features

- **Framework**: Node.js & Express
- **Database**: SQLite3 (native WAL mode with relational foreign keys and cascades)
- **Authentication**: JWT (JSON Web Tokens) with `bcryptjs` password hashing
- **Endpoints**:
  - `/api/auth/register`, `/api/auth/login`, `/api/auth/me`
  - `/api/notes` (CRUD + search + filter by folder/trash/archive)
  - `/api/folders` (CRUD)
  - `/api/tags` (CRUD)
  - `/api/sync/push` (Batch sync client notes to cloud)
  - `/api/sync/pull` (Fetch full cloud state)
  - `/health` (Health check)
  - `/` (Interactive Web Dashboard with database metrics & live API documentation)

---

## 🛠️ How to Run the Backend

### Prerequisites
- Node.js (v18+)

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Start the Server
```bash
npm start
```
The server will start at:
- **Local URL**: `http://localhost:5000`
- **Network / Emulator URL**: `http://10.0.2.2:5000` (Android emulator) or `http://<YOUR_LAN_IP>:5000`

### 3. Open the Interactive API Dashboard
Open your web browser and visit:
👉 **`http://localhost:5000`**

You will see:
- Real-time database metrics (User count, Note count, Folder count, Tag count).
- Full interactive API reference table.
- System health status.

---

## 🔒 Security
- Passwords are salted and hashed using `bcryptjs` before storage.
- Private routes are protected with JWT bearer tokens.
- SQL injection protection via parameterized queries (`DatabaseSync.prepare`).
