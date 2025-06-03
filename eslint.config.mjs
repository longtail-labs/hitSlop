import { defineConfig } from 'eslint/config';
import reactRefresh from 'eslint-plugin-react-refresh';
import tsPlugin from '@typescript-eslint/eslint-plugin';
import tsParser from '@typescript-eslint/parser';
import js from '@eslint/js';
import globals from 'globals';

// Clean up globals to remove any whitespace in keys
const cleanGlobals = (globalsObj) => {
  return Object.entries(globalsObj).reduce((acc, [key, value]) => {
    const cleanKey = key.trim();
    acc[cleanKey] = value;
    return acc;
  }, {});
};

export default defineConfig([
  // Ignore patterns
  {
    ignores: ['**/dist/**', '**/node_modules/**'],
  },

  // Base configuration for all files
  {
    extends: [js.configs.recommended],
    languageOptions: {
      globals: {
        ...cleanGlobals(globals.browser),
      },
    },
  },

  // TypeScript files configuration
  {
    files: ['**/*.ts', '**/*.tsx'],
    plugins: {
      '@typescript-eslint': tsPlugin,
      'react-refresh': reactRefresh,
    },
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    rules: {
      'react-refresh/only-export-components': [
        'warn',
        {
          allowConstantExport: true,
        },
      ],
      '@typescript-eslint/no-unused-vars': [
        'warn',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
]);
