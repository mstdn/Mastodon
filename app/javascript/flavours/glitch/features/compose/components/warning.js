import React from 'react';
import PropTypes from 'prop-types';
import Motion from '../../ui/util/optional_motion';
import spring from 'react-motion/lib/spring';

export default class Warning extends React.PureComponent {

  static propTypes = {
    message: PropTypes.node.isRequired,
  };

  render () {
    const { message } = this.props;

    return (
      <Motion defaultStyle={{ opacity: 0, scaleX: 0.85, scaleY: 0.75 }} style={{ opacity: spring(1, { damping: 35, stiffness: 400 }), scaleX: spring(1, { damping: 35, stiffness: 400 }), scaleY: spring(1, { damping: 35, stiffness: 400 }) }}>
        {({ opacity, scaleX, scaleY }) => (
          <div className='composer--warning' style={{ opacity: opacity, transform: `scale(${scaleX}, ${scaleY})` }}>
            {message}
          </div>
        )}
      </Motion>
    );
  }

}
