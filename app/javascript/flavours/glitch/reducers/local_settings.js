//  Package imports.
import { Map as ImmutableMap } from 'immutable';

//  Our imports.
import { STORE_HYDRATE } from 'flavours/glitch/actions/store';
import { LOCAL_SETTING_CHANGE } from 'flavours/glitch/actions/local_settings';

const initialState = ImmutableMap({
  layout    : 'auto',
  stretch   : true,
  navbar_under : false,
  swipe_to_change_columns: true,
  side_arm  : 'none',
  side_arm_reply_mode : 'keep',
  show_reply_count : true,
  always_show_spoilers_field: false,
  confirm_missing_media_description: false,
  confirm_boost_missing_media_description: false,
  confirm_before_clearing_draft: true,
  prepend_cw_re: true,
  preselect_on_reply: true,
  inline_preview_cards: true,
  hicolor_privacy_icons: true,
  show_content_type_choice: true,
  filtering_behavior: 'hide',
  tag_misleading_links: false,
  rewrite_mentions: 'no',
  content_warnings : ImmutableMap({
    auto_unfold : false,
    filter      : null,
  }),
  collapsed : ImmutableMap({
    enabled     : false,
    auto        : ImmutableMap({
      all              : false,
      notifications    : false,
      lengthy          : false,
      reblogs          : false,
      replies          : false,
      media            : false,
    }),
    backgrounds : ImmutableMap({
      user_backgrounds : false,
      preview_images   : false,
    }),
    show_action_bar : true,
  }),
  media     : ImmutableMap({
    letterbox        : true,
    fullwidth        : true,
    reveal_behind_cw : false,
    pop_in_player    : true,
    pop_in_position  : 'right',
  }),
  notifications : ImmutableMap({
    favicon_badge : false,
    tab_badge     : true,
  }),
});

const hydrate = (state, localSettings) => state.mergeDeep(localSettings);

export default function localSettings(state = initialState, action) {
  switch(action.type) {
  case STORE_HYDRATE:
    return hydrate(state, action.state.get('local_settings'));
  case LOCAL_SETTING_CHANGE:
    return state.setIn(action.key, action.value);
  default:
    return state;
  }
};
