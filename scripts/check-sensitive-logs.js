import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const targetDirectories = [
  path.join(rootDir, 'app blushy', 'backend', 'src'),
  path.join(rootDir, 'website blushy', 'backend', 'src'),
];

const sensitivePattern = /(?:password|token|otp|secret|authorization|creditCard|cvv|ssn|privateKey|bearer)/i;
const logPattern = /(?:logger\.(?:info|debug|warn|error)|console\.(?:log|warn|error|debug|info))\s*\(/i;

const allowedPatterns = [
  /\[REDACTED\]/i,
  /redact/i,
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

function getJsFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      if (file !== 'node_modules') {
        results = results.concat(getJsFiles(filePath));
      }
    } else if (file.endsWith('.js')) {
      results.push(filePath);
    }
  }
  return results;
}

let violationCount = 0;

console.log('🔒 Running Pre-commit Sensitive Data Log Redaction Audit...');

for (const targetDir of targetDirectories) {
  const files = getJsFiles(targetDir);
  for (const filePath of files) {
    const relPath = path.relative(rootDir, filePath);
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    lines.forEach((line, index) => {
      if (logPattern.test(line) && sensitivePattern.test(line)) {
        const isAllowed = allowedPatterns.some((pattern) => pattern.test(line));
        if (!isAllowed) {
          console.error(`❌ Security Violation in [${relPath}:${index + 1}]`);
          console.error(`   Line: ${line.trim()}`);
          console.error(`   Reason: Unredacted sensitive keyword found in log call.\n`);
          violationCount++;
        }
      }
    });
  }
}

if (violationCount > 0) {
  console.error(`🚫 Pre-commit Audit Failed: ${violationCount} potential sensitive log leaks detected.`);
  process.exit(1);
} else {
  console.log('✅ Security Log Audit Passed: No unredacted sensitive variables in logs.');
  process.exit(0);
}
