//  Package imports.
import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import { FormattedMessage } from 'react-intl';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { HotKeys } from 'react-hotkeys';
import classNames from 'classnames';

// Our imports.
import Permalink from 'flavours/glitch/components/permalink';
import AccountContainer from 'flavours/glitch/containers/account_container';
import NotificationOverlayContainer from '../containers/overlay_container';
import Icon from 'flavours/glitch/components/icon';

export default class NotificationFollow extends ImmutablePureComponent {

  static propTypes = {
    hidden: PropTypes.bool,
    id: PropTypes.string.isRequired,
    account: ImmutablePropTypes.map.isRequired,
    notification: ImmutablePropTypes.map.isRequired,
    unread: PropTypes.bool,
  };

  handleMoveUp = () => {
    const { notification, onMoveUp } = this.props;
    onMoveUp(notification.get('id'));
  }

  handleMoveDown = () => {
    const { notification, onMoveDown } = this.props;
    onMoveDown(notification.get('id'));
  }

  handleOpen = () => {
    this.handleOpenProfile();
  }

  handleOpenProfile = () => {
    const { notification } = this.props;
    this.context.router.history.push(`/@${notification.getIn(['account', 'acct'])}`);
  }

  handleMention = e => {
    e.preventDefault();

    const { notification, onMention } = this.props;
    onMention(notification.get('account'), this.context.router.history);
  }

  getHandlers () {
    return {
      moveUp: this.handleMoveUp,
      moveDown: this.handleMoveDown,
      open: this.handleOpen,
      openProfile: this.handleOpenProfile,
      mention: this.handleMention,
      reply: this.handleMention,
    };
  }

  render () {
    const { account, notification, hidden, unread } = this.props;

    //  Links to the display name.
    const displayName = account.get('display_name_html') || account.get('username');
    const link = (
      <bdi><Permalink
        className='notification__display-name'
        href={account.get('url')}
        title={account.get('acct')}
        to={`/@${account.get('acct')}`}
        dangerouslySetInnerHTML={{ __html: displayName }}
      /></bdi>
    );

    //  Renders.
    return (
      <HotKeys handlers={this.getHandlers()}>
        <div className={classNames('notification notification-follow focusable', { unread })} tabIndex='0'>
          <div className='notification__message'>
            <div className='notification__favourite-icon-wrapper'>
              <Icon fixedWidth id='user-plus' />
            </div>

            <FormattedMessage
              id='notification.follow'
              defaultMessage='{name} followed you'
              values={{ name: link }}
            />
          </div>

          <AccountContainer hidden={hidden} id={account.get('id')} withNote={false} />
          <NotificationOverlayContainer notification={notification} />
        </div>
      </HotKeys>
    );
  }

}
