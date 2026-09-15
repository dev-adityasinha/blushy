import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

/**
 * Directories this audit is responsible for.
 *
 * These used to name `app blushy/backend/src` and `website blushy/backend/src`,
 * which are from an older layout and no longer exist. A missing directory
 * yielded an empty file list, so the audit inspected nothing and reported that
 * it had passed -- for every commit, on both halves of the codebase.
 *
 * `required` is what stops that happening again: a path that disappears in a
 * future reshuffle now fails the audit instead of quietly emptying it.
 */
const targetDirectories = [
  { dir: path.join(rootDir, 'BLUSHY_MAINAPP', 'backend', 'src'), required: true },
  { dir: path.join(rootDir, 'BLUSHY_MAINAPP', 'lib'), required: true },
];

/** Source extensions to read. Dart is the app; JS is the backend. */
const scannedExtensions = ['.js', '.mjs', '.dart'];

/**
 * A secret being interpolated into the log, rather than merely mentioned.
 *
 * The old rule flagged any log line containing the word "password" or "token",
 * which meant `logger.info('Password reset code sent for ${email}')` -- which
 * logs an address, not a code -- was a violation, while a line that actually
 * interpolated a secret looked no different. A scanner that cries wolf is one
 * somebody switches off, so this matches the expression inside `${...}`.
 *
 * `code` is deliberately narrow: `rawCode` and `verificationCode` are secrets,
 * `statusCode` and `languageCode` are not, and the codebase is full of the
 * latter.
 */
const sensitiveInterpolation =
  /\$\{[^}]*(?:password|passwd|token|secret|apikey|api_key|privatekey|bearer|credential|cvv|ssn|(?:raw|verification|reset|otp|pass|access|auth)code)[^}]*\}/i;

/**
 * Anything that writes to a log the user's device or our servers keep.
 *
 * `debugPrint` and `print` are the Flutter half. debugPrint reaches logcat,
 * which on many devices other processes can read and anyone with the phone
 * plugged in certainly can -- it is not a private channel because the build is
 * a debug build.
 */
const logPattern = /(?:logger\.(?:info|debug|warn|error)|console\.(?:log|warn|error|debug|info)|debugPrint|developer\.log|(?<![.\w])print)\s*\(/i;

/**
 * Whole response bodies, which carry whatever the endpoint returned.
 *
 * The keyword scan above cannot see these: `${response.data}` mentions nothing
 * sensitive by name, yet it printed the signup verification code, the
 * onboarding answers and Docsy's replies about a user's health. Interpolating
 * a body into a log is the violation, whatever the body happens to hold.
 */
const bodyPattern = /\$\{?\s*(?:response\.data|response\.body|res\.data|res\.body)\s*\}?/;

/**
 * An exemption written where the code is, not in a list over here.
 *
 * This scanner reads one line at a time, so it cannot see that a log sits
 * inside `if (env.nodeEnv !== 'production')` or that an interpolation resolves
 * to the word "set" rather than the key it is testing. Rather than grow a
 * central list of message fragments that drifts out of step with the code,
 * a line may carry:
 *
 *     // sensitive-log-ok: <why>
 *
 * which puts the justification next to the thing being justified, where a
 * reviewer reading the log call will see it.
 */
const inlineExemption = /\/\/\s*sensitive-log-ok:/i;

const allowedPatterns = [
  /\[REDACTED\]/i,
  /redact/i,
  /shapeOf\(/,            // logs key names only -- see lib/services/log_redaction.dart
  /tokenVersion/i,
  /signAccessToken/i,
  /signRefreshToken/i,
  /signVerificationToken/i,
  /verifyVerificationToken/i,
  /verifyRefreshToken/i,
  /verificationTokenHash/i,
  /tokenType/i,
  /tokenMatches/i,
  /check-sensitive-logs/i,
  /token_id/i,
  /token_count/i,
  /HIBP password breach/i,
  /Password reset completed/i,
];

function getSourceFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  for (const file of fs.readdirSync(dir)) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      // Generated localisations are machine-written and hold no log calls.
      if (file !== 'node_modules' && file !== 'build' && file !== '.dart_tool') {
        results = results.concat(getSourceFiles(filePath));
      }
    } else if (scannedExtensions.some((ext) => file.endsWith(ext))) {
      results.push(filePath);
    }
  }
  return results;
}

let violationCount = 0;
let scannedFiles = 0;

console.log('🔒 Running Pre-commit Sensitive Data Log Redaction Audit...');

for (const { dir, required } of targetDirectories) {
  if (!fs.existsSync(dir)) {
    if (required) {
      console.error(`❌ Configured audit directory is missing: ${path.relative(rootDir, dir)}`);
      console.error('   The audit cannot vouch for code it never read. Fix the path in scripts/check-sensitive-logs.js.\n');
      violationCount++;
    }
    continue;
  }

  for (const filePath of getSourceFiles(dir)) {
    const relPath = path.relative(rootDir, filePath);
    scannedFiles += 1;
    const lines = fs.readFileSync(filePath, 'utf-8').split('\n');

    lines.forEach((line, index) => {
      if (!logPattern.test(line)) return;

      const keyword = sensitiveInterpolation.test(line);
      const wholeBody = bodyPattern.test(line);
      if (!keyword && !wholeBody) return;
      if (inlineExemption.test(line)) return;
      if (allowedPatterns.some((pattern) => pattern.test(line))) return;

      console.error(`❌ Security Violation in [${relPath}:${index + 1}]`);
      console.error(`   Line: ${line.trim()}`);
      console.error(
        `   Reason: ${keyword
          ? 'A secret is interpolated into this log call.'
          : 'Whole response body interpolated into a log call; log its shape instead.'}\n`,
      );
      violationCount++;
    });
  }
}

console.log(`   scanned ${scannedFiles} file(s) across ${targetDirectories.length} directories`);

if (violationCount > 0) {
  console.error(`🚫 Pre-commit Audit Failed: ${violationCount} potential sensitive log leaks detected.`);
  process.exit(1);
} else {
  console.log('✅ Security Log Audit Passed: No unredacted sensitive variables in logs.');
  process.exit(0);
}
