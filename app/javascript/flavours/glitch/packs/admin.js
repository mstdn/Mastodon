import 'packs/public-path';
import loadPolyfills from 'flavours/glitch/util/load_polyfills';
import ready from 'flavours/glitch/util/ready';
import loadKeyboardExtensions from 'flavours/glitch/util/load_keyboard_extensions';

function main() {
  const { delegate } = require('@rails/ujs');

  ready(() => {
    const React    = require('react');
    const ReactDOM = require('react-dom');

    [].forEach.call(document.querySelectorAll('[data-admin-component]'), element => {
      const componentName  = element.getAttribute('data-admin-component');
      const { locale, ...componentProps } = JSON.parse(element.getAttribute('data-props'));

      import('flavours/glitch/containers/admin_component').then(({ default: AdminComponent }) => {
        return import('flavours/glitch/components/admin/' + componentName).then(({ default: Component }) => {
          ReactDOM.render((
            <AdminComponent locale={locale}>
              <Component {...componentProps} />
            </AdminComponent>
          ), element);
        });
      }).catch(error => {
        console.error(error);
      });
    });
  });

  delegate(document, '.sidebar__toggle__icon', 'click', () => {
    const target = document.querySelector('.sidebar ul');

    if (target.style.display === 'block') {
      target.style.display = 'none';
    } else {
      target.style.display = 'block';
    }
  });
}

loadPolyfills()
  .then(main)
  .then(loadKeyboardExtensions)
  .catch(error => {
    console.error(error);

  });
