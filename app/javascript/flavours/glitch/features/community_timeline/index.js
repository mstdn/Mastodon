import React from 'react';
import { connect } from 'react-redux';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import StatusListContainer from 'flavours/glitch/features/ui/containers/status_list_container';
import Column from 'flavours/glitch/components/column';
import ColumnHeader from 'flavours/glitch/components/column_header';
import { expandCommunityTimeline } from 'flavours/glitch/actions/timelines';
import { addColumn, removeColumn, moveColumn } from 'flavours/glitch/actions/columns';
import ColumnSettingsContainer from './containers/column_settings_container';
import { connectCommunityStream } from 'flavours/glitch/actions/streaming';
import { Helmet } from 'react-helmet';
import { title } from 'flavours/glitch/initial_state';

const messages = defineMessages({
  title: { id: 'column.community', defaultMessage: 'Local timeline' },
});

const mapStateToProps = (state, { columnId }) => {
  const uuid = columnId;
  const columns = state.getIn(['settings', 'columns']);
  const index = columns.findIndex(c => c.get('uuid') === uuid);
  const onlyMedia = (columnId && index >= 0) ? columns.get(index).getIn(['params', 'other', 'onlyMedia']) : state.getIn(['settings', 'community', 'other', 'onlyMedia']);
  const regex = (columnId && index >= 0) ? columns.get(index).getIn(['params', 'regex', 'body']) : state.getIn(['settings', 'community', 'regex', 'body']);
  const timelineState = state.getIn(['timelines', `community${onlyMedia ? ':media' : ''}`]);

  return {
    hasUnread: !!timelineState && timelineState.get('unread') > 0,
    onlyMedia,
    regex,
  };
};

export default @connect(mapStateToProps)
@injectIntl
class CommunityTimeline extends React.PureComponent {

  static defaultProps = {
    onlyMedia: false,
  };

  static contextTypes = {
    router: PropTypes.object,
    identity: PropTypes.object,
  };

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    columnId: PropTypes.string,
    intl: PropTypes.object.isRequired,
    hasUnread: PropTypes.bool,
    multiColumn: PropTypes.bool,
    onlyMedia: PropTypes.bool,
    regex: PropTypes.string,
  };

  handlePin = () => {
    const { columnId, dispatch, onlyMedia } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('COMMUNITY', { other: { onlyMedia } }));
    }
  }

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  }

  handleHeaderClick = () => {
    this.column.scrollTop();
  }

  componentDidMount () {
    const { dispatch, onlyMedia } = this.props;
    const { signedIn } = this.context.identity;

    dispatch(expandCommunityTimeline({ onlyMedia }));

    if (signedIn) {
      this.disconnect = dispatch(connectCommunityStream({ onlyMedia }));
    }
  }

  componentDidUpdate (prevProps) {
    const { signedIn } = this.context.identity;

    if (prevProps.onlyMedia !== this.props.onlyMedia) {
      const { dispatch, onlyMedia } = this.props;

      if (this.disconnect) {
        this.disconnect();
      }

      dispatch(expandCommunityTimeline({ onlyMedia }));

      if (signedIn) {
        this.disconnect = dispatch(connectCommunityStream({ onlyMedia }));
      }
    }
  }

  componentWillUnmount () {
    if (this.disconnect) {
      this.disconnect();
      this.disconnect = null;
    }
  }

  setRef = c => {
    this.column = c;
  }

  handleLoadMore = maxId => {
    const { dispatch, onlyMedia } = this.props;

    dispatch(expandCommunityTimeline({ maxId, onlyMedia }));
  }

  render () {
    const { intl, hasUnread, columnId, multiColumn, onlyMedia } = this.props;
    const pinned = !!columnId;

    return (
      <Column ref={this.setRef} name='local' bindToDocument={!multiColumn} label={intl.formatMessage(messages.title)}>
        <ColumnHeader
          icon='users'
          active={hasUnread}
          title={intl.formatMessage(messages.title)}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
        >
          <ColumnSettingsContainer columnId={columnId} />
        </ColumnHeader>

        <StatusListContainer
          trackScroll={!pinned}
          scrollKey={`community_timeline-${columnId}`}
          timelineId={`community${onlyMedia ? ':media' : ''}`}
          onLoadMore={this.handleLoadMore}
          emptyMessage={<FormattedMessage id='empty_column.community' defaultMessage='The local timeline is empty. Write something publicly to get the ball rolling!' />}
          bindToDocument={!multiColumn}
          regex={this.props.regex}
        />

        <Helmet>
          <title>{intl.formatMessage(messages.title)} - {title}</title>
        </Helmet>
      </Column>
    );
  }

}
