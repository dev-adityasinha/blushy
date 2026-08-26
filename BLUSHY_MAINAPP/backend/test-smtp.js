import dotenv from 'dotenv';
import nodemailer from 'nodemailer';

dotenv.config({ path: './.env' });

const host = process.env.SMTP_HOST || 'smtp.gmail.com';
const port = Number(process.env.SMTP_PORT) || 587;
const user = process.env.SMTP_USER;
const pass = process.env.SMTP_PASSWORD;
const from = process.env.EMAIL_FROM || user;
const to = process.env.SMTP_TEST_TO || user;

const transporter = nodemailer.createTransport({
  host,
  port,
  secure: port === 465,
  auth: user && pass ? { user, pass } : undefined,
  tls: { rejectUnauthorized: false },
  connectionTimeout: 10000,
});

(async () => {
  try {
    console.log('SMTP config:', { host, port, user, from, to });
    console.log('Verifying transport...');
    await transporter.verify();
    console.log('Transport verified — sending test mail...');
    const info = await transporter.sendMail({
      from: `\"Blushy\" <${from}>`,
      to,
      subject: 'Blushy SMTP test',
      text: 'This is a Blushy SMTP test message from website backend.',
    });
    console.log('Send result:', info);
  } catch (err) {
    console.error('SMTP error details:');
    console.error(err);
  }
  process.exit(0);
})();