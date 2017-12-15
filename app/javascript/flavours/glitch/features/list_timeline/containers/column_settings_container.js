import { connect } from 'react-redux';
import ColumnSettings from '../components/column_settings';
import { changeSetting, saveSettings } from 'flavours/glitch/actions/settings';

const mapStateToProps = state => ({
  settings: state.getIn(['settings', 'list_timeline']),
});

const mapDispatchToProps = dispatch => ({

  onChange (key, checked) {
    dispatch(changeSetting(['list_timeline', ...key], checked));
  },

  onSave () {
    dispatch(saveSettings());
  },

});

export default connect(mapStateToProps, mapDispatchToProps)(ColumnSettings);
