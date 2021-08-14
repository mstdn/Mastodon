import { connect }   from 'react-redux';
import { defineMessages, injectIntl } from 'react-intl';
import NavigationBar from '../components/navigation_bar';
import { logOut } from 'mastodon/utils/log_out';
import { openModal } from 'mastodon/actions/modal';
import { me } from '../../../initial_state';

const messages = defineMessages({
  logoutMessage: { id: 'confirmations.logout.message', defaultMessage: 'Are you sure you want to log out?' },
  logoutConfirm: { id: 'confirmations.logout.confirm', defaultMessage: 'Log out' },
});

const mapStateToProps = state => {
  return {
    account: state.getIn(['accounts', me]),
  };
};

const mapDispatchToProps = (dispatch, { intl }) => ({
  onLogout () {
    dispatch(openModal('CONFIRM', {
      message: intl.formatMessage(messages.logoutMessage),
      confirm: intl.formatMessage(messages.logoutConfirm),
      closeWhenConfirm: false,
      onConfirm: () => logOut(),
    }));
  },
});

export default injectIntl(connect(mapStateToProps, mapDispatchToProps)(NavigationBar));
