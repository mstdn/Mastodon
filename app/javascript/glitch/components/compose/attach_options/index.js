//  Package imports  //
import React from 'react';
import PropTypes from 'prop-types';
import { injectIntl, defineMessages } from 'react-intl';

//  Our imports  //
import ComposeDropdown from '../dropdown/index';

//  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

const messages = defineMessages({
  upload :
    { id: 'compose.attach.upload', defaultMessage: 'Upload a file' },
  doodle :
    { id: 'compose.attach.doodle', defaultMessage: 'Draw something' },
  attach :
    { id: 'compose.attach', defaultMessage: 'Attach...' },
});


@injectIntl
export default class ComposeAttachOptions extends React.PureComponent {

  static propTypes = {
    intl     : PropTypes.object.isRequired,
  };

  handleClick = e => {
    const bt = e.target.datset.index;
    //TODO
  };

  render () {
    const { intl } = this.props;

    const options = [
      { icon: 'cloud-upload', text: messages.upload, name: 'upload' },
      { icon: 'paint-brush', text: messages.doodle, name: 'doodle' },
    ];

    const optionElems = options.map((item) => {
      return (
        <div
          role='button'
          tabIndex='0'
          key={item.name}
          data-index={item.name}
          onClick={this.handleClick}
          className='privacy-dropdown__option'
        >
          <div className='privacy-dropdown__option__icon'>
            <i className={`fa fa-fw fa-${item.icon}`} />
          </div>

          <div className='privacy-dropdown__option__content'>
            <strong>{item.text}</strong>
          </div>
        </div>
      );
    });

    return (
      <ComposeDropdown
        title={intl.formatMessage(messages.attach)}
        icon='paperclip'
      >
        {optionElems}
      </ComposeDropdown>
    );
  }

}
