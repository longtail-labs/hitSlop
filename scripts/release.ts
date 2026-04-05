#!/usr/bin/env bun
import { execSync } from 'child_process';
import { readVersion, writeVersion, bumpVersion } from './lib/version';

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

// --- Bump version ---
const bumpType = (['patch', 'minor', 'major'] as const).find(t => process.argv.includes(t)) ?? 'patch';
const oldVersion = readVersion();
const newVersion = bumpVersion(oldVersion, bumpType);
writeVersion(newVersion);
console.log(`📦 ${oldVersion} → ${newVersion} (${bumpType})`);

// --- Stage changes ---
const staged = exec('git diff --cached --name-only', { silent: true });
if (!staged) {
  exec('git add -u');
}
exec('git add version.txt');

// --- Generate commit message ---
const diff = exec('git diff --cached --stat', { silent: true });
const files = exec('git diff --cached --name-only', { silent: true });
const fallback = `🚀 chore: release v${newVersion}`;

let message = fallback;
try {
  const prompt = `You are writing a git commit message for hitSlop, a macOS .slop document viewer built with SwiftUI + HyperClay templates.

Changes being committed:
${diff}

Files changed:
${files}

Write a single-line commit message (no quotes, no prefix emoji). Be specific about what changed — mention the actual code changes, not just the version bump.`;

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
  // timeout or claude not available — use fallback
}

console.log(`💬 ${message}`);

// --- Commit and push ---
execSync(`git commit -m ${JSON.stringify(message)}`, { stdio: 'inherit' });
execSync('git push origin master', { stdio: 'inherit' });

console.log(`\n✅ Released v${newVersion}`);
