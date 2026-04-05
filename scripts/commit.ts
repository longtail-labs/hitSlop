#!/usr/bin/env bun
import { execSync } from 'child_process';

function exec(cmd: string, opts?: { silent?: boolean; timeout?: number }): string {
  try {
    return execSync(cmd, {
      encoding: 'utf-8',
      stdio: opts?.silent ? 'pipe' : 'inherit',
      timeout: opts?.timeout,
    }).toString().trim();
  } catch {
    return '';
  }
}

// --- Require staged files ---
const files = exec('git diff --cached --name-only', { silent: true });
if (!files) {
  console.error('❌ Nothing staged. Use `git add` first.');
  process.exit(1);
}

const fileList = files.split('\n').filter(Boolean);
console.log(`📝 ${fileList.length} file(s) staged`);

// --- Generate commit message ---
const diff = exec('git diff --cached --stat', { silent: true });
let message = '';

try {
  const prompt = `You are writing a git commit message for hitSlop, a macOS .slop document viewer built with SwiftUI + HyperClay templates.

Changes being committed:
${diff}

Files changed:
${files}

Write a single-line commit message (no quotes, no prefix emoji). Be specific about what changed.`;

  const ai = execSync('claude -p', {
    input: prompt,
    encoding: 'utf-8',
    timeout: 30_000,
    stdio: ['pipe', 'pipe', 'pipe'],
  }).toString().trim();
  const line = ai.split('\n').pop()?.trim() ?? '';
  if (line.length > 5 && line.length < 200 && !line.startsWith('Error')) {
    message = line;
  }
} catch {
  // timeout or claude not available
}

// --- Fallback: classify by file patterns ---
if (!message) {
  const dominant = fileList.some(f => /test/i.test(f)) ? 'test'
    : fileList.some(f => /\.md$/i.test(f)) ? 'docs'
    : fileList.some(f => /package\.json|lock/i.test(f)) ? 'chore'
    : fileList.some(f => /\.css|\.scss|theme/i.test(f)) ? 'style'
    : 'feat';

  const shortNames = fileList.slice(0, 3).map(f => f.split('/').pop()).join(', ');
  const extra = fileList.length > 3 ? ` +${fileList.length - 3} more` : '';
  message = `${dominant}: update ${shortNames}${extra}`;
}

console.log(`💬 ${message}`);

// --- Commit (no push) ---
execSync(`git commit -m ${JSON.stringify(message)}`, { stdio: 'inherit' });
console.log('✅ Committed');
