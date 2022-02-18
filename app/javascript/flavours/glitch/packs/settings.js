import 'packs/public-path';
import loadPolyfills from 'flavours/glitch/util/load_polyfills';
import ready from 'flavours/glitch/util/ready';
import loadKeyboardExtensions from 'flavours/glitch/util/load_keyboard_extensions';

function main() {
  const { delegate } = require('@rails/ujs');

  delegate(document, '.sidebar__toggle__icon', 'click', () => {
    document.querySelector('.sidebar ul').classList.toggle('visible');
  });
}

loadPolyfills()
  .then(main)
  .then(loadKeyboardExtensions)
  .catch(error => {
    console.error(error);
  });
