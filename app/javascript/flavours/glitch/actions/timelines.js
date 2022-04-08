import { importFetchedStatus, importFetchedStatuses } from './importer';
import { submitMarkers } from './markers';
import api, { getLinks } from 'flavours/glitch/util/api';
import { Map as ImmutableMap, List as ImmutableList } from 'immutable';
import compareId from 'flavours/glitch/util/compare_id';
import { me, usePendingItems as preferPendingItems } from 'flavours/glitch/util/initial_state';
import { getFiltersRegex } from 'flavours/glitch/selectors';
import { searchTextFromRawStatus } from 'flavours/glitch/actions/importer/normalizer';

export const TIMELINE_UPDATE  = 'TIMELINE_UPDATE';
export const TIMELINE_DELETE  = 'TIMELINE_DELETE';
export const TIMELINE_CLEAR   = 'TIMELINE_CLEAR';

export const TIMELINE_EXPAND_REQUEST = 'TIMELINE_EXPAND_REQUEST';
export const TIMELINE_EXPAND_SUCCESS = 'TIMELINE_EXPAND_SUCCESS';
export const TIMELINE_EXPAND_FAIL    = 'TIMELINE_EXPAND_FAIL';

export const TIMELINE_SCROLL_TOP   = 'TIMELINE_SCROLL_TOP';
export const TIMELINE_LOAD_PENDING = 'TIMELINE_LOAD_PENDING';
export const TIMELINE_DISCONNECT   = 'TIMELINE_DISCONNECT';
export const TIMELINE_CONNECT      = 'TIMELINE_CONNECT';

export const TIMELINE_MARK_AS_PARTIAL = 'TIMELINE_MARK_AS_PARTIAL';

export const loadPending = timeline => ({
  type: TIMELINE_LOAD_PENDING,
  timeline,
});

export function updateTimeline(timeline, status, accept) {
  return (dispatch, getState) => {
    if (typeof accept === 'function' && !accept(status)) {
      return;
    }

    if (getState().getIn(['timelines', timeline, 'isPartial'])) {
      // Prevent new items from being added to a partial timeline,
      // since it will be reloaded anyway

      return;
    }

    const filters   = getFiltersRegex(getState(), { contextType: timeline });
    const dropRegex = filters[0];
    const regex     = filters[1];
    const text      = searchTextFromRawStatus(status);
    let filtered    = false;

    if (status.account.id !== me) {
      filtered = (dropRegex && dropRegex.test(text)) || (regex && regex.test(text));
    }

    dispatch(importFetchedStatus(status));

    dispatch({
      type: TIMELINE_UPDATE,
      timeline,
      status,
      usePendingItems: preferPendingItems,
      filtered
    });

    if (timeline === 'home') {
      dispatch(submitMarkers());
    }
  };
};

export function deleteFromTimelines(id) {
  return (dispatch, getState) => {
    const accountId  = getState().getIn(['statuses', id, 'account']);
    const references = getState().get('statuses').filter(status => status.get('reblog') === id).map(status => status.get('id'));
    const reblogOf   = getState().getIn(['statuses', id, 'reblog'], null);

    dispatch({
      type: TIMELINE_DELETE,
      id,
      accountId,
      references,
      reblogOf,
    });
  };
};

export function clearTimeline(timeline) {
  return (dispatch) => {
    dispatch({ type: TIMELINE_CLEAR, timeline });
  };
};

const noOp = () => {};

const parseTags = (tags = {}, mode) => {
  return (tags[mode] || []).map((tag) => {
    return tag.value;
  });
};

export function expandTimeline(timelineId, path, params = {}, done = noOp) {
  return (dispatch, getState) => {
    const timeline = getState().getIn(['timelines', timelineId], ImmutableMap());
    const isLoadingMore = !!params.max_id;

    if (timeline.get('isLoading')) {
      done();
      return;
    }

    if (!params.max_id && !params.pinned && (timeline.get('items', ImmutableList()).size + timeline.get('pendingItems', ImmutableList()).size) > 0) {
      const a = timeline.getIn(['pendingItems', 0]);
      const b = timeline.getIn(['items', 0]);

      if (a && b && compareId(a, b) > 0) {
        params.since_id = a;
      } else {
        params.since_id = b || a;
      }
    }

    const isLoadingRecent = !!params.since_id;

    dispatch(expandTimelineRequest(timelineId, isLoadingMore));

    api(getState).get(path, { params }).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedStatuses(response.data));
      dispatch(expandTimelineSuccess(timelineId, response.data, next ? next.uri : null, response.status === 206, isLoadingRecent, isLoadingMore, isLoadingRecent && preferPendingItems));

      if (timelineId === 'home') {
        dispatch(submitMarkers());
      }
    }).catch(error => {
      dispatch(expandTimelineFail(timelineId, error, isLoadingMore));
    }).finally(() => {
      done();
    });
  };
};

export function fillTimelineGaps(timelineId, path, params = {}, done = noOp) {
  return (dispatch, getState) => {
    const timeline = getState().getIn(['timelines', timelineId], ImmutableMap());
    const items = timeline.get('items');
    const nullIndexes = items.map((statusId, index) => statusId === null ? index : null);
    const gaps = nullIndexes.map(index => index > 0 ? items.get(index - 1) : null);

    // Only expand at most two gaps to avoid doing too many requests
    done = gaps.take(2).reduce((done, maxId) => {
      return (() => dispatch(expandTimeline(timelineId, path, { ...params, maxId }, done)));
    }, done);

    done();
  };
}

export const expandHomeTimeline            = ({ maxId } = {}, done = noOp) => expandTimeline('home', '/api/v1/timelines/home', { max_id: maxId }, done);
export const expandPublicTimeline          = ({ maxId, onlyMedia, onlyRemote, allowLocalOnly } = {}, done = noOp) => expandTimeline(`public${onlyRemote ? ':remote' : (allowLocalOnly ? ':allow_local_only' : '')}${onlyMedia ? ':media' : ''}`, '/api/v1/timelines/public', { remote: !!onlyRemote, allow_local_only: !!allowLocalOnly, max_id: maxId, only_media: !!onlyMedia }, done);
export const expandCommunityTimeline       = ({ maxId, onlyMedia } = {}, done = noOp) => expandTimeline(`community${onlyMedia ? ':media' : ''}`, '/api/v1/timelines/public', { local: true, max_id: maxId, only_media: !!onlyMedia }, done);
export const expandDirectTimeline          = ({ maxId } = {}, done = noOp) => expandTimeline('direct', '/api/v1/timelines/direct', { max_id: maxId }, done);
export const expandAccountTimeline         = (accountId, { maxId, withReplies } = {}) => expandTimeline(`account:${accountId}${withReplies ? ':with_replies' : ''}`, `/api/v1/accounts/${accountId}/statuses`, { exclude_replies: !withReplies, max_id: maxId });
export const expandAccountFeaturedTimeline = accountId => expandTimeline(`account:${accountId}:pinned`, `/api/v1/accounts/${accountId}/statuses`, { pinned: true });
export const expandAccountMediaTimeline    = (accountId, { maxId } = {}) => expandTimeline(`account:${accountId}:media`, `/api/v1/accounts/${accountId}/statuses`, { max_id: maxId, only_media: true, limit: 40 });
export const expandListTimeline            = (id, { maxId } = {}, done = noOp) => expandTimeline(`list:${id}`, `/api/v1/timelines/list/${id}`, { max_id: maxId }, done);
export const expandHashtagTimeline         = (hashtag, { maxId, tags, local } = {}, done = noOp) => {
  return expandTimeline(`hashtag:${hashtag}${local ? ':local' : ''}`, `/api/v1/timelines/tag/${hashtag}`, {
    max_id: maxId,
    any: parseTags(tags, 'any'),
    all: parseTags(tags, 'all'),
    none: parseTags(tags, 'none'),
    local: local,
  }, done);
};

export const fillHomeTimelineGaps      = (done = noOp) => fillTimelineGaps('home', '/api/v1/timelines/home', {}, done);
export const fillPublicTimelineGaps    = ({ onlyMedia, onlyRemote, allowLocalOnly } = {}, done = noOp) => fillTimelineGaps(`public${onlyRemote ? ':remote' : (allowLocalOnly ? ':allow_local_only' : '')}${onlyMedia ? ':media' : ''}`, '/api/v1/timelines/public', { remote: !!onlyRemote, only_media: !!onlyMedia, allow_local_only: !!allowLocalOnly }, done);
export const fillCommunityTimelineGaps = ({ onlyMedia } = {}, done = noOp) => fillTimelineGaps(`community${onlyMedia ? ':media' : ''}`, '/api/v1/timelines/public', { local: true, only_media: !!onlyMedia }, done);
export const fillListTimelineGaps      = (id, done = noOp) => fillTimelineGaps(`list:${id}`, `/api/v1/timelines/list/${id}`, {}, done);

export function expandTimelineRequest(timeline, isLoadingMore) {
  return {
    type: TIMELINE_EXPAND_REQUEST,
    timeline,
    skipLoading: !isLoadingMore,
  };
};

export function expandTimelineSuccess(timeline, statuses, next, partial, isLoadingRecent, isLoadingMore, usePendingItems) {
  return {
    type: TIMELINE_EXPAND_SUCCESS,
    timeline,
    statuses,
    next,
    partial,
    isLoadingRecent,
    usePendingItems,
    skipLoading: !isLoadingMore,
  };
};

export function expandTimelineFail(timeline, error, isLoadingMore) {
  return {
    type: TIMELINE_EXPAND_FAIL,
    timeline,
    error,
    skipLoading: !isLoadingMore,
    skipNotFound: timeline.startsWith('account:'),
  };
};

export function scrollTopTimeline(timeline, top) {
  return {
    type: TIMELINE_SCROLL_TOP,
    timeline,
    top,
  };
};

export function connectTimeline(timeline) {
  return {
    type: TIMELINE_CONNECT,
    timeline,
    usePendingItems: preferPendingItems,
  };
};

export const disconnectTimeline = timeline => ({
  type: TIMELINE_DISCONNECT,
  timeline,
  usePendingItems: preferPendingItems,
});

export const markAsPartial = timeline => ({
  type: TIMELINE_MARK_AS_PARTIAL,
  timeline,
});
