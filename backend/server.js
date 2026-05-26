require("dotenv").config({ path: "./app.env" });

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const path = require("path");
const { Pool } = require("pg");

const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const app = express();
const PORT = process.env.PORT || 5000;

let pool;

// ─── Middleware ─────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(morgan("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── Get DB Secret from AWS Secrets Manager ─────────────────
async function getSecret() {
  const client = new SecretsManagerClient({
    region: process.env.AWS_REGION,
  });

  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: process.env.SECRET_NAME,
    })
  );

  return JSON.parse(response.SecretString);
}

// ─── Create PostgreSQL Pool ─────────────────
async function createPool() {
  const secret = await getSecret();

  const dbPool = new Pool({
    host: secret.host,
    port: parseInt(secret.port),
    database: secret.dbname,
    user: secret.username,
    password: secret.password,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    max: 10,
  });

  dbPool.on("error", (err) => {
    console.error("Unexpected DB pool error:", err.message);
  });

  return dbPool;
}

// ─── Health Check API ───────────────────────
app.get("/api/health", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT NOW() AS db_time, version() AS db_version"
    );

    res.json({
      status: "healthy",
      database: "connected",
      db_time: result.rows[0].db_time,
      db_version: result.rows[0].db_version,
      environment: process.env.NODE_ENV,
    });
  } catch (err) {
    res.status(500).json({
      status: "unhealthy",
      database: "disconnected",
      error: err.message,
    });
  }
});
// ─── USERS API ─────────────────────────────

// Get all users
app.get("/api/users", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM users ORDER BY id ASC"
    );

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

// Create user
app.post("/api/users", async (req, res) => {
  try {
    const { name, email, role } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        success: false,
        error: "Name and email required",
      });
    }

    const result = await pool.query(
      "INSERT INTO users (name, email, role) VALUES ($1, $2, $3) RETURNING *",
      [name, email, role || "user"]
    );

    res.status(201).json({
      success: true,
      data: result.rows[0],
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

// Delete user
app.delete("/api/users/:id", async (req, res) => {
  try {
    const { id } = req.params;

    await pool.query("DELETE FROM users WHERE id = $1", [id]);

    res.json({
      success: true,
      message: "User deleted",
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

// ─── Serve Frontend ─────────────────────────
app.use(express.static(path.join(__dirname, "../frontend")));

app.get("/api/users", async (req, res) => {
  const result = await pool.query("SELECT * FROM users ORDER BY id");
  res.json({ success: true, data: result.rows });
});
app.get("/api/products", async (req, res) => {
  const result = await pool.query("SELECT * FROM products ORDER BY id");
  res.json({ success: true, data: result.rows });
});
app.get("/api/orders", async (req, res) => {
  const result = await pool.query(`
    SELECT o.*, u.name as user_name, p.name as product_name
    FROM orders o
    JOIN users u ON o.user_id = u.id
    JOIN products p ON o.product_id = p.id
    ORDER BY o.id DESC
  `);

  res.json({ success: true, data: result.rows });
});
app.get("*", (req, res) => {
  res.sendFile(
    path.join(__dirname, "../frontend/index.html")
  );
});

// ─── Start Server ───────────────────────────
async function startServer() {
  try {
    console.log("Fetching DB credentials from Secrets Manager...");

    pool = await createPool();

    await pool.query("SELECT NOW()");
    console.log("Database connected successfully");

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Environment: ${process.env.NODE_ENV}`);
    });
  } catch (err) {
    console.error("Server startup failed:", err.message);
    process.exit(1);
  }
}

startServer();
