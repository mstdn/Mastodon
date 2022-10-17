import { List as ImmutableList, fromJS as ConvertToImmutable } from 'immutable';
import { CUSTOM_EMOJIS_FETCH_SUCCESS } from 'flavours/glitch/actions/custom_emojis';
import { search as emojiSearch } from 'flavours/glitch/features/emoji/emoji_mart_search_light';
import { buildCustomEmojis } from 'flavours/glitch/features/emoji/emoji';

const initialState = ImmutableList([]);

export default function custom_emojis(state = initialState, action) {
  if(action.type === CUSTOM_EMOJIS_FETCH_SUCCESS) {
    state = ConvertToImmutable(action.custom_emojis);
    emojiSearch('', { custom: buildCustomEmojis(state) });
  }

  return state;
};
