#!/usr/bin/env bun
import { select, input, confirm } from '@inquirer/prompts';
import { execSync } from 'child_process';

interface CommitType {
  value: string;
  name: string;
  description: string;
}

const COMMIT_TYPES: CommitType[] = [
  { value: 'feat', name: 'feat', description: 'A new feature' },
  { value: 'fix', name: 'fix', description: 'A bug fix' },
  { value: 'docs', name: 'docs', description: 'Documentation only changes' },
  { value: 'style', name: 'style', description: 'Code style changes (formatting, etc)' },
  { value: 'refactor', name: 'refactor', description: 'Code refactoring' },
  { value: 'perf', name: 'perf', description: 'Performance improvements' },
  { value: 'test', name: 'test', description: 'Adding or updating tests' },
  { value: 'build', name: 'build', description: 'Build system or dependencies' },
  { value: 'ci', name: 'ci', description: 'CI configuration changes' },
  { value: 'chore', name: 'chore', description: 'Other changes' },
];

function exec(command: string): string {
  try {
    return execSync(command, { encoding: 'utf-8' }).trim();
  } catch (error) {
    return '';
  }
}

function getStagedFiles(): string[] {
  const output = exec('git diff --cached --name-only');
  return output ? output.split('\n').filter(Boolean) : [];
}

function getUnstagedFiles(): string[] {
  const output = exec('git diff --name-only');
  return output ? output.split('\n').filter(Boolean) : [];
}

function getUntrackedFiles(): string[] {
  const output = exec('git ls-files --others --exclude-standard');
  return output ? output.split('\n').filter(Boolean) : [];
}

async function main() {
  console.log('\n🎯 Interactive Git Commit Helper\n');

  // Check for staged files
  let stagedFiles = getStagedFiles();

  if (stagedFiles.length === 0) {
    console.log('⚠️  No files are currently staged for commit.');

    const unstagedFiles = getUnstagedFiles();
    const untrackedFiles = getUntrackedFiles();

    if (unstagedFiles.length === 0 && untrackedFiles.length === 0) {
      console.log('✨ Working directory is clean. Nothing to commit.');
      process.exit(0);
    }

    console.log('\nModified files:');
    if (unstagedFiles.length > 0) {
      unstagedFiles.forEach((file) => console.log(`  - ${file}`));
    }
    if (untrackedFiles.length > 0) {
      console.log('\nUntracked files:');
      untrackedFiles.forEach((file) => console.log(`  - ${file}`));
    }

    const shouldStage = await confirm({
      message: 'Would you like to stage all changes?',
      default: true,
    });

    if (shouldStage) {
      exec('git add -A');
      stagedFiles = getStagedFiles();
      console.log(`\n✓ Staged ${stagedFiles.length} file(s)`);
    } else {
      console.log('\n👋 Exiting without committing.');
      process.exit(0);
    }
  }

  console.log('\nStaged files:');
  stagedFiles.forEach((file) => console.log(`  - ${file}`));
  console.log('');

  // Select commit type
  const type = await select({
    message: 'Select commit type:',
    choices: COMMIT_TYPES.map((t) => ({
      value: t.value,
      name: t.name,
      description: t.description,
    })),
  });

  // Optional scope
  const scope = await input({
    message: 'Scope (optional, e.g., "auth", "ui", "api"):',
    required: false,
  });

  // Commit message
  const message = await input({
    message: 'Commit message (short description):',
    required: true,
    validate: (value) => {
      if (!value || value.trim().length === 0) {
        return 'Commit message is required';
      }
      if (value.trim().length < 3) {
        return 'Commit message must be at least 3 characters';
      }
      return true;
    },
  });

  // Optional body
  const hasBody = await confirm({
    message: 'Add detailed description?',
    default: false,
  });

  let body = '';
  if (hasBody) {
    body = await input({
      message: 'Detailed description (optional):',
      required: false,
    });
  }

  // Build commit message
  const scopePart = scope ? `(${scope})` : '';
  const fullMessage = `${type}${scopePart}: ${message.trim()}`;
  const commitMessage = body ? `${fullMessage}\n\n${body}` : fullMessage;

  // Preview
  console.log('\n📝 Commit preview:');
  console.log('─'.repeat(50));
  console.log(commitMessage);
  console.log('─'.repeat(50));

  const shouldCommit = await confirm({
    message: 'Create this commit?',
    default: true,
  });

  if (shouldCommit) {
    try {
      execSync(`git commit -m "${commitMessage.replace(/"/g, '\\"')}"`, {
        stdio: 'inherit',
      });
      console.log('\n✅ Commit created successfully!');
    } catch (error) {
      console.error('\n❌ Failed to create commit:', error);
      process.exit(1);
    }
  } else {
    console.log('\n👋 Commit cancelled.');
  }
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
