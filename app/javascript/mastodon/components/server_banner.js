import React from 'react';
import PropTypes from 'prop-types';
import { domain } from 'mastodon/initial_state';
import { fetchServer } from 'mastodon/actions/server';
import { connect } from 'react-redux';
import Account from 'mastodon/containers/account_container';
import ShortNumber from 'mastodon/components/short_number';
import Skeleton from 'mastodon/components/skeleton';
import { FormattedMessage, injectIntl, defineMessages } from 'react-intl';

const messages = defineMessages({
  aboutActiveUsers: { id: 'server_banner.about_active_users', defaultMessage: 'People using this server during the last 30 days (Monthly Active Users)' },
});

const mapStateToProps = state => ({
  server: state.get('server'),
});

export default @connect(mapStateToProps)
@injectIntl
class ServerBanner extends React.PureComponent {

  static propTypes = {
    server: PropTypes.object,
    dispatch: PropTypes.func,
    intl: PropTypes.object,
  };

  componentDidMount () {
    const { dispatch } = this.props;
    dispatch(fetchServer());
  }

  render () {
    const { server, intl } = this.props;
    const isLoading = server.get('isLoading');

    return (
      <div className='server-banner'>
        <div className='server-banner__introduction'>
          <FormattedMessage id='server_banner.introduction' defaultMessage='{domain} is part of the decentralized social network powered by {mastodon}.' values={{ domain: <strong>{domain}</strong>, mastodon: <a href='https://joinmastodon.org' target='_blank'>Mastodon</a> }} />
        </div>

        <img src={server.get('thumbnail')} alt={server.get('title')} className='server-banner__hero' />

        <div className='server-banner__description'>
          {isLoading ? (
            <>
              <Skeleton width='100%' />
              <br />
              <Skeleton width='100%' />
              <br />
              <Skeleton width='70%' />
            </>
          ) : server.get('description')}
        </div>

        <div className='server-banner__meta'>
          <div className='server-banner__meta__column'>
            <h4><FormattedMessage id='server_banner.administered_by' defaultMessage='Administered by:' /></h4>

            <Account id={server.getIn(['contact', 'account', 'id'])} />
          </div>

          <div className='server-banner__meta__column'>
            <h4><FormattedMessage id='server_banner.server_stats' defaultMessage='Server stats:' /></h4>

            {isLoading ? (
              <>
                <strong className='server-banner__number'><Skeleton width='10ch' /></strong>
                <br />
                <span className='server-banner__number-label'><Skeleton width='5ch' /></span>
              </>
            ) : (
              <>
                <strong className='server-banner__number'><ShortNumber value={server.getIn(['usage', 'users', 'active_month'])} /></strong>
                <br />
                <span className='server-banner__number-label' title={intl.formatMessage(messages.aboutActiveUsers)}><FormattedMessage id='server_banner.active_users' defaultMessage='active users' /></span>
              </>
            )}
          </div>
        </div>

        <hr className='spacer' />

        <a className='button button--block button-secondary' href='/about/more' target='_blank'><FormattedMessage id='server_banner.learn_more' defaultMessage='Learn more' /></a>
      </div>
    );
  }

}
