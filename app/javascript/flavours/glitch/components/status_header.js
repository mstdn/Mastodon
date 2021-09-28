//  Package imports.
import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';

//  Mastodon imports.
import Avatar from './avatar';
import AvatarOverlay from './avatar_overlay';
import AvatarComposite from './avatar_composite';
import DisplayName from './display_name';

export default class StatusHeader extends React.PureComponent {

  static propTypes = {
    status: ImmutablePropTypes.map.isRequired,
    friend: ImmutablePropTypes.map,
    parseClick: PropTypes.func.isRequired,
    otherAccounts: ImmutablePropTypes.list,
  };

  //  Handles clicks on account name/image
  handleClick = (acct, e) => {
    const { parseClick } = this.props;
    parseClick(e, `/@${acct}`);
  }

  handleAccountClick = (e) => {
    const { status } = this.props;
    this.handleClick(status.getIn(['account', 'acct']), e);
  }

  //  Rendering.
  render () {
    const {
      status,
      friend,
      otherAccounts,
    } = this.props;

    const account = status.get('account');

    let statusAvatar;
    if (otherAccounts && otherAccounts.size > 0) {
      statusAvatar = <AvatarComposite accounts={otherAccounts} size={48} onAccountClick={this.handleClick} />;
    } else if (friend === undefined || friend === null) {
      statusAvatar = <Avatar account={account} size={48} />;
    } else {
      statusAvatar = <AvatarOverlay account={account} friend={friend} />;
    }

    if (!otherAccounts) {
      return (
        <div className='status__info__account'>
          <a
            href={account.get('url')}
            target='_blank'
            className='status__avatar'
            onClick={this.handleAccountClick}
            rel='noopener noreferrer'
          >
            {statusAvatar}
          </a>
          <a
            href={account.get('url')}
            target='_blank'
            className='status__display-name'
            onClick={this.handleAccountClick}
            rel='noopener noreferrer'
          >
            <DisplayName account={account} others={otherAccounts} />
          </a>
        </div>
      );
    } else {
      // This is a DM conversation
      return (
        <div className='status__info__account'>
          <span className='status__avatar'>
            {statusAvatar}
          </span>

          <span className='status__display-name'>
            <DisplayName account={account} others={otherAccounts} onAccountClick={this.handleClick} />
          </span>
        </div>
      );
    }
  }

}
