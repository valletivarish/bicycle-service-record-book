import js from '@eslint/js';
import security from 'eslint-plugin-security';
import globals from 'globals';

export default [
  js.configs.recommended,
  security.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module',
      globals: globals.node,
    },
    rules: {
      // Express recognises an error handler by its four arguments.
      'no-unused-vars': ['error', { argsIgnorePattern: '^(req|next)$' }],
    },
  },
];
