import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';
import { FormattedMessage } from 'react-intl';
import { closeModal } from 'mastodon/actions/modal';
import emojify from 'mastodon/features/emoji/emoji';
import escapeTextContentForBrowser from 'escape-html';
import InlineAccount from 'mastodon/components/inline_account';
import IconButton from 'mastodon/components/icon_button';
import RelativeTimestamp from 'mastodon/components/relative_timestamp';

const mapStateToProps = (state, { statusId }) => ({
  versions: state.getIn(['history', statusId, 'items']),
});

const mapDispatchToProps = dispatch => ({

  onClose() {
    dispatch(closeModal());
  },

});

export default @connect(mapStateToProps, mapDispatchToProps)
class CompareHistoryModal extends React.PureComponent {

  static propTypes = {
    onClose: PropTypes.func.isRequired,
    index: PropTypes.number.isRequired,
    statusId: PropTypes.string.isRequired,
    versions: ImmutablePropTypes.list.isRequired,
  };

  render () {
    const { index, versions, onClose } = this.props;
    const currentVersion = versions.get(index);

    const emojiMap = currentVersion.get('emojis').reduce((obj, emoji) => {
      obj[`:${emoji.get('shortcode')}:`] = emoji.toJS();
      return obj;
    }, {});

    const content = { __html: emojify(currentVersion.get('content'), emojiMap) };
    const spoilerContent = { __html: emojify(escapeTextContentForBrowser(currentVersion.get('spoiler_text')), emojiMap) };

    const formattedDate = <RelativeTimestamp timestamp={currentVersion.get('created_at')} short={false} />;
    const formattedName = <InlineAccount accountId={currentVersion.get('account')} />;

    const label = currentVersion.get('original') ? (
      <FormattedMessage id='status.history.created' defaultMessage='{name} created {date}' values={{ name: formattedName, date: formattedDate }} />
    ) : (
      <FormattedMessage id='status.history.edited' defaultMessage='{name} edited {date}' values={{ name: formattedName, date: formattedDate }} />
    );

    return (
      <div className='modal-root__modal compare-history-modal'>
        <div className='report-modal__target'>
          <IconButton className='report-modal__close' icon='times' onClick={onClose} size={20} />
          {label}
        </div>

        <div className='compare-history-modal__container'>
          <div className='status__content'>
            {currentVersion.get('spoiler_text').length > 0 && (
              <React.Fragment>
                <div className='translate' dangerouslySetInnerHTML={spoilerContent} />
                <hr />
              </React.Fragment>
            )}

            <div className='status__content__text status__content__text--visible translate' dangerouslySetInnerHTML={content} />
          </div>
        </div>
      </div>
    );
  }

}
