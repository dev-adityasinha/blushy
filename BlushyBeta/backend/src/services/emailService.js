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
      rejectUnauthorized: false,
    },
    auth: env.smtpUser && env.smtpPassword
      ? {
          user: env.smtpUser,
          pass: env.smtpPassword,
        }
      : undefined,
  };
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

async function sendVerificationLink(email, verificationLink, code = null) {
  const transportCandidates = createTransportCandidates();
  if (transportCandidates.length === 0) {
    if (allowDevFallback()) {
      if (verificationLink) {
        logger.info(`DEV email verification link for ${email}: ${verificationLink} (OTP code: ${code})`);
      }
      return { success: true, mode: 'dev-fallback' };
    }

    throw new Error('SMTP is not configured. Set SMTP_HOST and EMAIL_FROM for production email delivery.');
  }

  const subject = code ? `Your Blushy Verification Code: ${code}` : 'Verify your Blushy email';
  const text = [
    code ? `Your 6-digit verification code is: ${code}` : '',
    '',
    'Or click the link below to verify your email:',
    verificationLink ?? '',
    '',
    'This code/link expires in 10 minutes.',
  ].filter(Boolean).join('\n');

  let lastError = null;

  for (const options of transportCandidates) {
    const transport = nodemailer.createTransport(options);
    logger.info(`Attempting SMTP send using ${options.host}:${options.port} secure=${options.secure}`);

    const timeoutMs = Number.isFinite(env.smtpAttemptTimeout) ? env.smtpAttemptTimeout : 20000;
    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('SMTP attempt timed out')), timeoutMs));

    try {
      await Promise.race([
        transport.sendMail({
          from: env.emailFrom,
          to: email,
          subject,
          text,
          html: `
          <div style="font-family:Arial,sans-serif;line-height:1.5;color:#2b2b2b;max-width:500px;margin:0 auto;padding:20px;border:1px solid #f5d6de;border-radius:12px;background-color:#fff7f9;">
            <h2 style="margin:0 0 12px;color:#f76b8a;text-align:center;">Welcome to Blushy 🌸</h2>
            ${code ? `
            <p style="text-align:center;font-size:15px;color:#555;">Use the following 6-digit verification code to complete your signup:</p>
            <div style="text-align:center;margin:20px 0;">
              <span style="display:inline-block;font-size:32px;font-weight:bold;letter-spacing:6px;color:#f76b8a;background:#fff;padding:12px 24px;border-radius:8px;border:2px dashed #f76b8a;">${code}</span>
            </div>
            ` : ''}
            <p style="text-align:center;margin-top:16px;">Or click the button below to verify your account in your browser:</p>
            ${verificationLink ? `
            <div style="text-align:center;margin:16px 0;">
              <a href="${verificationLink}" style="display:inline-block;background-color:#f76b8a;color:#ffffff;text-decoration:none;padding:12px 28px;border-radius:24px;font-weight:bold;font-size:15px;">Verify Account</a>
            </div>
            <p style="margin-top:12px;font-size:12px;color:#888;word-break:break-all;text-align:center;"><a href="${verificationLink}" style="color:#f76b8a">${verificationLink}</a></p>
            ` : ''}
            <p style="margin-top:20px;font-size:12px;color:#888;text-align:center;">This verification code and link will expire in 10 minutes.</p>
          </div>
        `,
        }),
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

export const emailService = {
  hasSmtpConfig,
  sendVerificationLink,
};