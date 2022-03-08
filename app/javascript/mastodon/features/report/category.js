import React from 'react';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import Button from 'mastodon/components/button';
import Option from './components/option';

const messages = defineMessages({
  dislike: { id: 'report.reasons.dislike', defaultMessage: 'I don\'t like it' },
  dislike_description: { id: 'report.reasons.dislike_description', defaultMessage: 'It is not something you want to see' },
  spam: { id: 'report.reasons.spam', defaultMessage: 'It\'s spam' },
  spam_description: { id: 'report.reasons.spam_description', defaultMessage: 'Malicious links, fake engagement, or repetitive replies' },
  violation: { id: 'report.reasons.violation', defaultMessage: 'It violates server rules' },
  violation_description: { id: 'report.reasons.violation_description', defaultMessage: 'You are aware that it breaks specific rules' },
  other: { id: 'report.reasons.other', defaultMessage: 'It\'s something else' },
  other_description: { id: 'report.reasons.other_description', defaultMessage: 'The issue does not fit into other categories' },
  status: { id: 'report.category.title_status', defaultMessage: 'post' },
  account: { id: 'report.category.title_account', defaultMessage: 'profile' },
});

export default @injectIntl
class Category extends React.PureComponent {

  static propTypes = {
    onNextStep: PropTypes.func.isRequired,
    category: PropTypes.string,
    onChangeCategory: PropTypes.func.isRequired,
    startedFrom: PropTypes.oneOf(['status', 'account']),
    intl: PropTypes.object.isRequired,
  };

  handleNextClick = () => {
    const { onNextStep, category } = this.props;

    switch(category) {
    case 'dislike':
      onNextStep('thanks');
      break;
    case 'violation':
      onNextStep('rules');
      break;
    default:
      onNextStep('statuses');
      break;
    }
  };

  handleCategoryToggle = (value, checked) => {
    const { onChangeCategory } = this.props;

    if (checked) {
      onChangeCategory(value);
    }
  };

  render () {
    const { category, startedFrom, intl } = this.props;

    const options = [
      'dislike',
      'spam',
      'violation',
      'other',
    ];

    return (
      <React.Fragment>
        <h3 className='report-dialog-modal__title'><FormattedMessage id='report.category.title' defaultMessage="Tell us what's going on with this {type}" values={{ type: intl.formatMessage(messages[startedFrom]) }} /></h3>
        <p className='report-dialog-modal__lead'><FormattedMessage id='report.category.subtitle' defaultMessage='Choose the best match' /></p>

        <div>
          {options.map(item => (
            <Option
              key={item}
              name='category'
              value={item}
              checked={category === item}
              onToggle={this.handleCategoryToggle}
              label={intl.formatMessage(messages[item])}
              description={intl.formatMessage(messages[`${item}_description`])}
            />
          ))}
        </div>

        <div className='flex-spacer' />

        <div className='report-dialog-modal__actions'>
          <Button onClick={this.handleNextClick} disabled={category === null}><FormattedMessage id='report.next' defaultMessage='Next' /></Button>
        </div>
      </React.Fragment>
    );
  }

}
