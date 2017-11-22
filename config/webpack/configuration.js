// Common configuration for webpacker loaded from config/webpacker.yml

const { basename, dirname, join, resolve } = require('path');
const { env } = require('process');
const { safeLoad } = require('js-yaml');
const { readFileSync } = require('fs');
const glob = require('glob');

const configPath = resolve('config', 'webpacker.yml');
const loadersDir = join(__dirname, 'loaders');
const settings = safeLoad(readFileSync(configPath), 'utf8')[env.NODE_ENV];
const themeFiles = glob.sync('app/javascript/themes/*/theme.yml');
const themes = {};

const core = function () {
  const coreFile = resolve('app', 'javascript', 'core', 'theme.yml');
  const data = safeLoad(readFileSync(coreFile), 'utf8');
  if (!data.pack_directory) {
    data.pack_directory = dirname(coreFile);
  }
  return data.pack ? data : {};
}();

for (let i = 0; i < themeFiles.length; i++) {
  const themeFile = themeFiles[i];
  const data = safeLoad(readFileSync(themeFile), 'utf8');
  data.name = basename(dirname(themeFile));
  if (!data.pack_directory) {
    data.pack_directory = dirname(themeFile);
  }
  if (data.pack && typeof data.pack == 'object') {
    themes[data.name] = data;
  }
}

function removeOuterSlashes(string) {
  return string.replace(/^\/*/, '').replace(/\/*$/, '');
}

function formatPublicPath(host = '', path = '') {
  let formattedHost = removeOuterSlashes(host);
  if (formattedHost && !/^http/i.test(formattedHost)) {
    formattedHost = `//${formattedHost}`;
  }
  const formattedPath = removeOuterSlashes(path);
  return `${formattedHost}/${formattedPath}/`;
}

const output = {
  path: resolve('public', settings.public_output_path),
  publicPath: formatPublicPath(env.ASSET_HOST, settings.public_output_path),
};

module.exports = {
  settings,
  core,
  themes,
  env,
  loadersDir,
  output,
};
