#!/usr/bin/env bun
import { select, confirm } from '@inquirer/prompts';
import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { readVersion, writeVersion, parseVersion, bumpVersion, validateVersion } from './lib/version';

interface ReleaseOptions {
  local: boolean;
  ci: boolean;
  skipBuild: boolean;
  skipTag: boolean;
}

function exec(command: string, silent = false): string {
  try {
    return execSync(command, {
      encoding: 'utf-8',
      stdio: silent ? 'pipe' : 'inherit',
    }).trim();
  } catch (error: any) {
    if (silent) {
      return '';
    }
    throw error;
  }
}

function checkPrerequisites() {
  // Check if we're in a git repository
  if (!existsSync('.git')) {
    console.error('❌ Error: Not a git repository');
    process.exit(1);
  }

  // Check if version.txt exists
  if (!existsSync('version.txt')) {
    console.error('❌ Error: version.txt not found');
    process.exit(1);
  }

  // Check for uncommitted changes
  const status = exec('git status --porcelain', true);
  if (status) {
    console.error('❌ Error: You have uncommitted changes. Please commit or stash them first.');
    console.log('\nUncommitted changes:');
    console.log(status);
    process.exit(1);
  }
}

function parseArgs(): ReleaseOptions {
  const args = process.argv.slice(2);
  return {
    local: args.includes('--local'),
    ci: args.includes('--ci'),
    skipBuild: args.includes('--skip-build'),
    skipTag: args.includes('--skip-tag'),
  };
}

async function selectVersionBump(currentVersion: string): Promise<string> {
  const parsed = parseVersion(currentVersion);

  const choices = [
    {
      value: 'patch',
      name: `Patch (${bumpVersion(currentVersion, 'patch')})`,
      description: 'Bug fixes and minor changes',
    },
    {
      value: 'minor',
      name: `Minor (${bumpVersion(currentVersion, 'minor')})`,
      description: 'New features (backwards compatible)',
    },
    {
      value: 'major',
      name: `Major (${bumpVersion(currentVersion, 'major')})`,
      description: 'Breaking changes',
    },
  ];

  const bumpType = await select({
    message: 'Select version bump:',
    choices,
  });

  return bumpVersion(currentVersion, bumpType as 'major' | 'minor' | 'patch');
}

async function selectReleaseMode(): Promise<'local' | 'ci' | 'skip'> {
  const mode = await select({
    message: 'Select release mode:',
    choices: [
      {
        value: 'local',
        name: 'Local Build',
        description: 'Build and package locally with Conveyor',
      },
      {
        value: 'ci',
        name: 'CI Build',
        description: 'Push tag to trigger GitHub Actions',
      },
      {
        value: 'skip',
        name: 'Skip Build',
        description: 'Only bump version and create tag',
      },
    ],
  });

  return mode as 'local' | 'ci' | 'skip';
}

async function main() {
  console.log('\n🚀 hitSlop Release Script\n');

  // Parse command line arguments
  const options = parseArgs();

  // Check prerequisites
  checkPrerequisites();

  // Read current version
  const currentVersion = readVersion();
  console.log(`📦 Current version: ${currentVersion}`);

  if (!validateVersion(currentVersion)) {
    console.error(`❌ Invalid version format in version.txt: ${currentVersion}`);
    console.error('   Expected format: MAJOR.MINOR.PATCH (e.g., 0.1.4)');
    process.exit(1);
  }

  // Select new version
  const newVersion = await selectVersionBump(currentVersion);
  console.log(`📦 New version: ${newVersion}\n`);

  // Confirm version bump
  const confirmVersion = await confirm({
    message: `Bump version from ${currentVersion} to ${newVersion}?`,
    default: true,
  });

  if (!confirmVersion) {
    console.log('👋 Release cancelled.');
    process.exit(0);
  }

  // Write new version
  writeVersion(newVersion);
  console.log(`✓ Updated version.txt to ${newVersion}`);

  // Create git tag
  if (!options.skipTag) {
    const tagName = `v${newVersion}`;

    // Check if tag already exists
    const tagExists = exec(`git tag -l "${tagName}"`, true);
    if (tagExists) {
      console.error(`❌ Error: Tag ${tagName} already exists`);
      process.exit(1);
    }

    exec(`git tag -a "${tagName}" -m "Release version ${newVersion}"`);
    console.log(`✓ Created tag: ${tagName}`);
  }

  // Determine release mode
  let mode: 'local' | 'ci' | 'skip';
  if (options.local) {
    mode = 'local';
  } else if (options.ci) {
    mode = 'ci';
  } else if (options.skipBuild) {
    mode = 'skip';
  } else {
    mode = await selectReleaseMode();
  }

  console.log('');

  // Execute release based on mode
  switch (mode) {
    case 'local':
      console.log('🏗️  Building release locally with Conveyor...\n');

      // Check if Conveyor is installed
      try {
        exec('which conveyor', true);
      } catch {
        console.error('❌ Error: Conveyor not found. Please install it first:');
        console.error('   https://www.hydraulic.dev/docs/installation');
        process.exit(1);
      }

      // Run release script
      try {
        exec('./release.sh');
        console.log('\n✅ Local build complete!');
      } catch (error) {
        console.error('\n❌ Build failed:', error);
        process.exit(1);
      }
      break;

    case 'ci':
      console.log('🚀 Pushing tag to trigger CI build...\n');

      const tagName = `v${newVersion}`;
      const shouldPush = await confirm({
        message: `Push tag ${tagName} to origin to trigger GitHub Actions?`,
        default: true,
      });

      if (shouldPush) {
        exec(`git push origin "${tagName}"`);
        console.log('\n✅ Tag pushed! GitHub Actions will build and release.');
        console.log(`   Watch progress at: https://github.com/longtail-labs/hitSlop/actions`);
      } else {
        console.log('\n👋 Tag not pushed. You can push it manually later:');
        console.log(`   git push origin ${tagName}`);
      }
      break;

    case 'skip':
      console.log('⏭️  Skipping build. Version bumped and tag created.');
      console.log('\nNext steps:');
      console.log(`  1. Push tag: git push origin v${newVersion}`);
      console.log('  2. Or run local build: ./release.sh');
      break;
  }

  console.log('\n🎉 Release process complete!\n');
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
