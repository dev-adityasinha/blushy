const { Client } = require('pg');
const client = new Client({ connectionString: 'postgres://postgres:postgres@localhost:5432/blushy' });

client.connect()
  .then(() => client.query("SELECT '2026-04-24'::date as dt"))
  .then(res => {
    const dt = res.rows[0].dt;
    console.log('Object type:', typeof dt, dt instanceof Date);
    console.log('Value:', dt);
    console.log('toISOString:', dt.toISOString());
    console.log('Local string:', dt.toString());
  })
  .catch(console.error)
  .finally(() => client.end());
