import nodemailer from 'nodemailer';

import { env } from '../utils/env.js';
import { logger } from '../utils/logger.js';

function allowDevFallback() {
  return env.nodeEnv !== 'production';
}

function hasSmtpConfig() {
  return Boolean(env.smtpHost && env.emailFrom);
}

function buildTransportOptions(port, secure) {
  return {
    host: env.smtpHost,
    port,
    secure,
    requireTLS: !secure,
    // shorter timeouts to avoid long blocking on hosted platforms
    connectionTimeout: Number.isFinite(env.smtpConnectionTimeout) ? env.smtpConnectionTimeout : 20000,
    greetingTimeout: Number.isFinite(env.smtpGreetingTimeout) ? env.smtpGreetingTimeout : 20000,
    socketTimeout: Number.isFinite(env.smtpSocketTimeout) ? env.smtpSocketTimeout : 20000,
    tls: {
      minVersion: 'TLSv1.2',
      rejectUnauthorized: env.nodeEnv === 'production',
    },
    auth: env.smtpUser && env.smtpPassword
      ? {
          user: env.smtpUser,
          pass: env.smtpPassword,
        }
      : undefined,
  };
}

/**
 * Sends through Brevo's HTTP API.
 *
 * SMTP is the fragile part of email delivery from a hosted backend: providers
 * block outbound port 25/587 routinely, and from the client side a blocked
 * port is indistinguishable from a rejected password. An ordinary HTTPS POST
 * has neither problem, so this is tried first whenever a key is configured.
 *
 * Returns null when Brevo is not configured, so the caller falls through to
 * SMTP rather than treating "no key" as a delivery failure.
 */
async function deliverViaBrevo({ to, subject, text, html }) {
  if (!env.brevoApiKey || !env.emailFrom) return null;

  const timeoutMs = Number.isFinite(env.smtpAttemptTimeout) ? env.smtpAttemptTimeout : 20000;
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), timeoutMs);

  try {
    const response = await fetch(env.brevoApiUrl, {
      method: 'POST',
      headers: {
        'api-key': env.brevoApiKey,
        'content-type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({
        sender: { name: env.emailFromName, email: env.emailFrom },
        to: [{ email: to }],
        subject,
        textContent: text,
        htmlContent: html,
      }),
      signal: abort.signal,
    });

    if (!response.ok) {
      // Brevo explains refusals in the body -- an unverified sender address and
      // a bad key are the two common ones, and they need different fixes, so
      // the reason is logged rather than flattened into "send failed".
      const detail = await response.text().catch(() => '');
      throw new Error(`Brevo API responded ${response.status}: ${detail.slice(0, 300)}`);
    }

    logger.info(`Email sent to ${to} via the Brevo API`);
    return { success: true, transport: { provider: 'brevo' } };
  } finally {
    clearTimeout(timer);
  }
}

function createTransportCandidates() {
  if (!hasSmtpConfig()) {
    return [];
  }

  const preferredPort = Number.isFinite(env.smtpPort) ? env.smtpPort : 587;
  const candidates = [
    buildTransportOptions(preferredPort, preferredPort === 465),
  ];

  if (preferredPort !== 465) {
    candidates.push(buildTransportOptions(465, true));
  }

  if (preferredPort !== 587) {
    candidates.push(buildTransportOptions(587, false));
  }

  return candidates;
}

/**
 * Sends one message, trying each transport candidate in turn.
 *
 * Extracted from the verification mail so anything else that needs to send
 * (partner invites) gets the same fallback ladder, timeouts and dev fallback
 * rather than a second, subtly different copy.
 */
async function deliver({ to, subject, text, html, devLogLine }) {
  let brevoError = null;
  try {
    const sent = await deliverViaBrevo({ to, subject, text, html });
    if (sent) return sent;
  } catch (error) {
    // Fall through to SMTP rather than giving up: a deployment may have both
    // configured, and the second path may well work.
    brevoError = error;
    logger.warn('Brevo API send failed, falling back to SMTP', { message: error?.message });
  }

  const transportCandidates = createTransportCandidates();
  if (transportCandidates.length === 0) {
    if (brevoError && !allowDevFallback()) throw brevoError;
    if (allowDevFallback()) {
      logger.info(devLogLine ?? `DEV email for ${to}: ${subject}`);
      return { success: true, mode: 'dev-fallback' };
    }
    throw new Error('SMTP is not configured. Set SMTP_HOST and EMAIL_FROM for production email delivery.');
  }

  let lastError = null;

  for (const options of transportCandidates) {
    const transport = nodemailer.createTransport(options);
    logger.info(`Attempting SMTP send using ${options.host}:${options.port} secure=${options.secure}`);

    const timeoutMs = Number.isFinite(env.smtpAttemptTimeout) ? env.smtpAttemptTimeout : 20000;
    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('SMTP attempt timed out')), timeoutMs));

    try {
      await Promise.race([
        transport.sendMail({ from: env.emailFrom, to, subject, text, html }),
        timeoutPromise,
      ]);

      logger.info(`SMTP send succeeded using ${options.host}:${options.port}`);
      return { success: true, transport: { host: options.host, port: options.port, secure: options.secure } };
    } catch (error) {
      lastError = error;
      logger.warn(`SMTP send failed using ${options.host}:${options.port} secure=${options.secure}`, error);
    } finally {
      try {
        transport.close();
      } catch (_) {
        // ignore
      }
    }
  }

  if (lastError) {
    logger.error('All SMTP transport candidates failed', {
      message: lastError?.message,
      name: lastError?.name,
      stack: lastError?.stack,
    });
    throw lastError;
  }

  return { success: true };
}

/**
 * Tells someone a partner has invited them to connect.
 *
 * The invitation used to be written to the database and announced only over the
 * realtime channel, so unless the recipient already had the app open they were
 * never told anything had happened.
 */
async function sendPartnerInvite({ to, senderName, inviteUrl = null }) {
  const who = senderName && senderName.trim().length > 0 ? senderName.trim() : 'Someone';
  const subject = `${who} invited you to connect on Blushy`;

  const text = [
    `${who} has invited you to connect as partners on Blushy.`,
    '',
    inviteUrl ? `Accept the invitation here: ${inviteUrl}` : 'Open the Blushy app to accept the invitation.',
    '',
    'If you were not expecting this, you can ignore this email and nothing will be shared.',
  ].filter(Boolean).join('\n');

  const html = `
  <div style="font-family:Arial,sans-serif;line-height:1.5;color:#2b2b2b;max-width:500px;margin:0 auto;padding:20px;border:1px solid #f5d6de;border-radius:12px;background-color:#fff7f9;">
    <h2 style="margin:0 0 12px;color:#f76b8a;text-align:center;">${who} invited you to connect 💞</h2>
    <p style="text-align:center;font-size:15px;color:#555;">
      They would like to share parts of their Blushy journey with you. You choose what you see, and they choose what they share.
    </p>
    ${inviteUrl ? `
    <div style="text-align:center;margin:20px 0;">
      <a href="${inviteUrl}" style="display:inline-block;background-color:#f76b8a;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:24px;font-weight:bold;font-size:15px;">Accept invitation</a>
    </div>
    <p style="margin-top:12px;font-size:12px;color:#888;word-break:break-all;text-align:center;"><a href="${inviteUrl}" style="color:#f76b8a">${inviteUrl}</a></p>
    ` : `
    <p style="text-align:center;margin-top:16px;">Open the Blushy app and you will find the invitation waiting for you.</p>
    `}
    <p style="margin-top:20px;font-size:12px;color:#888;text-align:center;">If you were not expecting this, ignore this email. Nothing is shared until you accept.</p>
  </div>`;

  return deliver({
    to,
    subject,
    text,
    html,
    devLogLine: `DEV partner invite for ${to} from ${who}${inviteUrl ? `: ${inviteUrl}` : ''}`,
  });
}

/**
 * Welcomes someone the first time their account exists.
 *
 * Sent once, from the two places an account is actually created: finishing an
 * email signup, and a first Google sign-in. Deliberately not sent when the
 * code is merely requested, because at that point there is no account yet.
 *
 * Failure is swallowed by the caller: a welcome that does not arrive is not a
 * reason to fail a signup that has already succeeded.
 */
async function sendWelcome({ to, name = null }) {
  const who = name && name.trim().length > 0 ? name.trim() : 'you';
  const greeting = who === 'you' ? 'Welcome to Blushy' : `Welcome to Blushy, ${who}`;
  const subject = 'Welcome to Blushy 💗';

  const text = [
    `${greeting}.`,
    '',
    'We are so glad you are here.',
    '',
    'Blushy is a soft place to keep track of your body and your days. Log what',
    'you feel, as much or as little as you like, and it starts noticing the',
    'patterns with you. Docsy is here whenever you want to talk something',
    'through, at any hour.',
    '',
    'A few gentle things to know:',
    '- Nothing you write is shared with anyone unless you connect a partner and',
    '  choose what to share.',
    '- Your journal stays yours. You decide what Docsy remembers.',
    '- There is no streak to keep and nothing to fall behind on.',
    '',
    'Take your time. We are glad you found us.',
    '',
    'With love,',
    'The Blushy family',
  ].join('\n');

  const html = `
  <div style="font-family:Arial,sans-serif;line-height:1.6;color:#2b2b2b;max-width:500px;margin:0 auto;padding:24px;border:1px solid #f5d6de;border-radius:12px;background-color:#fff7f9;">
    <div style="text-align:center;font-size:34px;line-height:1;margin-bottom:8px;">💗</div>
    <h2 style="margin:0 0 6px;color:#f76b8a;text-align:center;font-size:22px;">${greeting}</h2>
    <p style="text-align:center;font-size:15px;color:#555;margin:0 0 20px;">
      We are so glad you are here.
    </p>

    <p style="font-size:14px;color:#555;margin:0 0 16px;">
      Blushy is a soft place to keep track of your body and your days. Log what you
      feel, as much or as little as you like, and it starts noticing the patterns
      with you. Docsy is here whenever you want to talk something through, at
      any hour.
    </p>

    <div style="background-color:#ffffff;border:1px solid #f5d6de;border-radius:12px;padding:16px;margin:20px 0;">
      <p style="margin:0 0 10px;font-size:13px;color:#f76b8a;font-weight:bold;letter-spacing:1px;">A FEW GENTLE THINGS</p>
      <p style="margin:0 0 8px;font-size:14px;color:#555;">Nothing you write is shared with anyone unless you connect a partner and choose what to share.</p>
      <p style="margin:0 0 8px;font-size:14px;color:#555;">Your journal stays yours. You decide what Docsy remembers.</p>
      <p style="margin:0;font-size:14px;color:#555;">There is no streak to keep and nothing to fall behind on.</p>
    </div>

    <p style="text-align:center;font-size:14px;color:#555;margin:0 0 4px;">Take your time. We are glad you found us.</p>
    <p style="text-align:center;font-size:14px;color:#f76b8a;margin:16px 0 0;font-weight:bold;">With love,<br/>The Blushy family</p>
  </div>`;

  return deliver({
    to,
    subject,
    text,
    html,
    devLogLine: `DEV welcome email for ${to}`,
  });
}

/**
 * Sends the signup / password-reset code.
 *
 * This carried its own copy of the SMTP ladder and never called `deliver()`,
 * so the Brevo transport added there did not apply to the one message that
 * matters most -- the OTP. It now builds the message and hands it to the
 * shared path like everything else.
 */
async function sendVerificationLink(email, verificationLink, code = null) {
  const subject = code ? `Your Blushy Verification Code: ${code}` : 'Verify your Blushy email';

  const text = [
    code ? `Your 6-digit verification code is: ${code}` : '',
    '',
    verificationLink ? 'Or click the link below to verify your email:' : '',
    verificationLink ?? '',
    '',
    'This code expires in 10 minutes.',
  ].filter(Boolean).join('\n');

  const html = `
  <div style="font-family:Arial,sans-serif;line-height:1.5;color:#2b2b2b;max-width:500px;margin:0 auto;padding:20px;border:1px solid #f5d6de;border-radius:12px;background-color:#fff7f9;">
    <h2 style="margin:0 0 12px;color:#f76b8a;text-align:center;">Welcome to Blushy</h2>
    ${code ? `
    <p style="text-align:center;font-size:15px;color:#555;">Use the following 6-digit verification code to complete your signup:</p>
    <div style="text-align:center;margin:20px 0;">
      <span style="display:inline-block;font-size:32px;font-weight:bold;letter-spacing:6px;color:#f76b8a;background:#fff;padding:12px 24px;border-radius:8px;border:2px dashed #f76b8a;">${code}</span>
    </div>
    ` : ''}
    ${verificationLink ? `
    <p style="text-align:center;margin-top:16px;">Or click the button below to verify your account in your browser:</p>
    <div style="text-align:center;margin:16px 0;">
      <a href="${verificationLink}" style="display:inline-block;background-color:#f76b8a;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:24px;font-weight:bold;font-size:15px;">Verify Account</a>
    </div>
    <p style="margin-top:12px;font-size:12px;color:#888;word-break:break-all;text-align:center;"><a href="${verificationLink}" style="color:#f76b8a">${verificationLink}</a></p>
    ` : ''}
    <p style="margin-top:20px;font-size:12px;color:#888;text-align:center;">This code will expire in 10 minutes.</p>
  </div>`;

  return deliver({
    to: email,
    subject,
    text,
    html,
    devLogLine: verificationLink
      ? `DEV email verification link for ${email}: ${verificationLink} (OTP code: ${code})`
      : `DEV verification code for ${email}: ${code}`,
  });
}


export const emailService = {
  hasSmtpConfig,
  deliver,
  sendVerificationLink,
  sendPartnerInvite,
  sendWelcome,
};