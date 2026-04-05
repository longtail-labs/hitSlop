import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

const VERSION_FILE = 'version.txt';

export interface SemanticVersion {
  major: number;
  minor: number;
  patch: number;
}

/**
 * Read version from version.txt
 */
export function readVersion(): string {
  try {
    const versionPath = join(process.cwd(), VERSION_FILE);
    const version = readFileSync(versionPath, 'utf-8').trim();
    return version;
  } catch (error) {
    throw new Error(`Failed to read ${VERSION_FILE}: ${error}`);
  }
}

/**
 * Write version to version.txt
 */
export function writeVersion(version: string): void {
  try {
    const versionPath = join(process.cwd(), VERSION_FILE);
    writeFileSync(versionPath, `${version}\n`, 'utf-8');
  } catch (error) {
    throw new Error(`Failed to write ${VERSION_FILE}: ${error}`);
  }
}

/**
 * Parse semantic version string
 */
export function parseVersion(version: string): SemanticVersion {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid version format: ${version}. Expected format: MAJOR.MINOR.PATCH`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

/**
 * Validate version format
 */
export function validateVersion(version: string): boolean {
  return /^\d+\.\d+\.\d+$/.test(version);
}

/**
 * Bump version
 */
export function bumpVersion(version: string, type: 'major' | 'minor' | 'patch'): string {
  const parsed = parseVersion(version);
  switch (type) {
    case 'major':
      return `${parsed.major + 1}.0.0`;
    case 'minor':
      return `${parsed.major}.${parsed.minor + 1}.0`;
    case 'patch':
      return `${parsed.major}.${parsed.minor}.${parsed.patch + 1}`;
  }
}
