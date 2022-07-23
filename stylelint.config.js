module.exports = {
  extends: ['stylelint-config-standard-scss'],
  ignoreFiles: [
    'app/javascript/styles/mastodon/reset.scss',
    'node_modules/**/*',
    'vendor/**/*',
  ],
  rules: {
    'at-rule-empty-line-before': null,
    'color-function-notation': null,
    'color-hex-length': null,
    'declaration-block-no-redundant-longhand-properties': null,
    'max-line-length': null,
    'no-descending-specificity': null,
    'no-duplicate-selectors': null,
    'number-max-precision': 8,
    'property-no-unknown': null,
    'property-no-vendor-prefix': null,
    'selector-class-pattern': null,
    'selector-id-pattern': null,
    'string-quotes': null,
    'value-keyword-case': null,
    'value-no-vendor-prefix': null,

    'scss/dollar-variable-empty-line-before': null,
    'scss/no-global-function-names': null,
  },
};
