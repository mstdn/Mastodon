import { connect } from 'react-redux';
import Upload from '../components/upload';
import { undoUploadCompose, initMediaEditModal } from 'flavours/glitch/actions/compose';
import { submitCompose } from 'flavours/glitch/actions/compose';

const mapStateToProps = (state, { id }) => ({
  media: state.getIn(['compose', 'media_attachments']).find(item => item.get('id') === id),
  isEditingStatus: state.getIn(['compose', 'id']) !== null,
});

const mapDispatchToProps = dispatch => ({

  onUndo: id => {
    dispatch(undoUploadCompose(id));
  },

  onOpenFocalPoint: id => {
    dispatch(initMediaEditModal(id));
  },

  onSubmit (router) {
    dispatch(submitCompose(router));
  },

});

export default connect(mapStateToProps, mapDispatchToProps)(Upload);
