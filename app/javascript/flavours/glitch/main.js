import React from 'react';
import ReactDOM from 'react-dom';
import { setupBrowserNotifications } from 'flavours/glitch/actions/notifications';
import Mastodon, { store } from 'flavours/glitch/containers/mastodon';
import ready from 'flavours/glitch/ready';

const perf = require('flavours/glitch/performance');

/**
 * @returns {Promise<void>}
 */
function main() {
  perf.start('main()');

  if (window.history && history.replaceState) {
    const { pathname, search, hash } = window.location;
    const path = pathname + search + hash;
    if (!(/^\/web($|\/)/).test(path)) {
      history.replaceState(null, document.title, `/web${path}`);
    }
  }

  return ready(async () => {
    const mountNode = document.getElementById('mastodon');
    const props = JSON.parse(mountNode.getAttribute('data-props'));

    ReactDOM.render(<Mastodon {...props} />, mountNode);
    store.dispatch(setupBrowserNotifications());

    if (process.env.NODE_ENV === 'production' && 'serviceWorker' in navigator) {
      const [{ Workbox }, { me }] = await Promise.all([
        import('workbox-window'),
        import('flavours/glitch/initial_state'),
      ]);

      const wb = new Workbox('/sw.js');

      try {
        await wb.register();
      } catch (err) {
        console.error(err);

        return;
      }

      if (me) {
        const registerPushNotifications = await import('flavours/glitch/actions/push_notifications');

        store.dispatch(registerPushNotifications.register());
      }
    }

    perf.stop('main()');
  });
}

export default main;
