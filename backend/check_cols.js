require('dotenv').config();
const oracledb = require('oracledb');

async function check() {
  let conn;
  try {
    conn = await oracledb.getConnection({
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      connectString: process.env.DB_CONNECTION_STRING
    });

    console.log('Testing query without APP_DESC and ADDRESS_DESC...');
    const result = await conn.execute(
      `SELECT oid, app_num, app_year, app_date, app_title, type_name 
       FROM tracking.apps_2016`,
      [],
      { fetchArraySize: 1000 }
    );
    console.log('✅ Success! Rows fetched:', result.rows.length);

  } catch (err) {
    console.error('❌ Failed:', err.message);
  } finally {
    if (conn) {
      await conn.close();
    }
  }
}
check();
