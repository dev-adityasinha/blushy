/**
 * Sends one real email so delivery can be checked without signing up.
 *
 * Delivery failures used to surface only as a signup that silently handed the
 * OTP back in the API response, which looked like it worked. This exercises the
 * same `deliver()` path the app uses -- Brevo first, SMTP as fallback -- and
 * says plainly which transport carried it.
 *
 * Run:
 *   node src/scripts/testEmailDelivery.mjs --to you@example.com
 */
import 'dotenv/config';
import { env } from '../utils/env.js';
import { emailService } from '../services/emailService.js';

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? null : process.argv[i + 1] ?? null;
}

async function main() {
  const to = (arg('to') ?? '').trim();
  if (!to.includes('@')) {
    console.error('Usage: node src/scripts/testEmailDelivery.mjs --to you@example.com');
    process.exit(1);
  }

  console.log(`brevo key : ${env.brevoApiKey ? 'set' : 'NOT SET'}`);
  console.log(`smtp host : ${env.smtpHost || 'NOT SET'}`);
  console.log(`from      : ${env.emailFrom || 'NOT SET'}`);
  console.log(`sending to: ${to}\n`);

  if (!env.brevoApiKey && !env.smtpHost) {
    console.error('Nothing is configured to send with. Set BREVO_API_KEY in .env.');
    process.exit(1);
  }

  try {
    // A real code shape, so what lands in the inbox is what a user would see.
    const result = await emailService.sendVerificationLink(to, null, '123456');
    console.log('\nSent.');
    console.log(`transport: ${JSON.stringify(result?.transport ?? result ?? {})}`);
    console.log('\nCheck the inbox, including spam. If it is not there within a');
    console.log('minute, the provider accepted it but did not deliver it --');
    console.log('that is usually an unverified sender address.');
    process.exit(0);
  } catch (error) {
    console.error('\nDelivery failed.');
    console.error(error?.message ?? error);
    console.error('\nCommon causes:');
    console.error('  - BREVO_API_KEY wrong or revoked        -> 401 from the API');
    console.error('  - EMAIL_FROM is not a verified sender   -> 400, "sender not valid"');
    console.error('  - Gmail SMTP without an App Password    -> 535 BadCredentials');
    process.exit(1);
  }
}

main();
