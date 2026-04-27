require('dotenv').config();
const express = require('express');
const oracledb = require('oracledb');
const cors = require('cors');

// إنشاء السيرفر
const app = express();
app.use(cors()); // Allow Flutter app to connect
app.use(express.json());

// ⚙️ إعدادات الاتصال بقاعدة بيانات أوراكل
const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectString: process.env.DB_CONNECTION_STRING
};

console.log("Configured to connect to Oracle at:", dbConfig.connectString);

// 📌 الرابط الأول: جلب المراسلات الأساسية
app.get('/api/apps_2016', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig);
    
    // سحب البيانات (ROWNUM <= 100 لتسريع العملية ومناسبة حدود الذكاء الاصطناعي)
    const result = await connection.execute(
      `SELECT * FROM tracking.apps_2016 WHERE ROWNUM <= 100`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    console.error("Error in apps_2016:", err);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (err) { console.error(err); }
    }
  }
});

// 📌 الرابط الثاني: جلب التحويلات
app.get('/api/transactions_2016', async (req, res) => {
  let connection;
  try {
    connection = await oracledb.getConnection(dbConfig);
    
    // سحب البيانات (ROWNUM <= 100 لتسريع العملية ومناسبة حدود الذكاء الاصطناعي)
    const result = await connection.execute(
      `SELECT * FROM tracking.apps_transactions_2016 WHERE ROWNUM <= 100`,
      [],
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    console.error("Error in transactions_2016:", err);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    if (connection) {
      try { await connection.close(); } catch (err) { console.error(err); }
    }
  }
});

app.get('/', (req, res) => {
  res.send('✅ خادم البلدية (Oracle API) يعمل بنجاح!');
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`);
});
