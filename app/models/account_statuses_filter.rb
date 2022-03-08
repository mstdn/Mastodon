# frozen_string_literal: true

class AccountStatusesFilter
  KEYS = %i(
    pinned
    tagged
    only_media
    exclude_replies
    exclude_reblogs
  ).freeze

  attr_reader :params, :account, :current_account

  def initialize(account, current_account, params = {})
    @account         = account
    @current_account = current_account
    @params          = params
  end

  def results
    scope = initial_scope

    scope.merge!(pinned_scope)     if pinned?
    scope.merge!(only_media_scope) if only_media?
    scope.merge!(no_replies_scope) if exclude_replies?
    scope.merge!(no_reblogs_scope) if exclude_reblogs?
    scope.merge!(hashtag_scope)    if tagged?

    scope
  end

  private

  def initial_scope
    if suspended?
      Status.none
    elsif anonymous?
      account.statuses.not_local_only.where(visibility: %i(public unlisted))
    elsif author?
      account.statuses.all # NOTE: #merge! does not work without the #all
    elsif blocked?
      Status.none
    else
      filtered_scope
    end
  end

  def filtered_scope
    scope = account.statuses.left_outer_joins(:mentions)

    scope.merge!(scope.where(visibility: follower? ? %i(public unlisted private) : %i(public unlisted)).or(scope.where(mentions: { account_id: current_account.id })).group(Status.arel_table[:id]))
    scope.merge!(filtered_reblogs_scope) if reblogs_may_occur?

    scope
  end

  def filtered_reblogs_scope
    Status.left_outer_joins(:reblog).where(reblog_of_id: nil).or(Status.where.not(reblogs_statuses: { account_id: current_account.excluded_from_timeline_account_ids }))
  end

  def only_media_scope
    Status.joins(:media_attachments).merge(account.media_attachments.reorder(nil)).group(Status.arel_table[:id])
  end

  def no_replies_scope
    Status.without_replies
  end

  def no_reblogs_scope
    Status.without_reblogs
  end

  def pinned_scope
    account.pinned_statuses.group(Status.arel_table[:id], StatusPin.arel_table[:created_at])
  end

  def hashtag_scope
    tag = Tag.find_normalized(params[:tagged])

    if tag
      Status.tagged_with(tag.id)
    else
      Status.none
    end
  end

  def suspended?
    account.suspended?
  end

  def anonymous?
    current_account.nil?
  end

  def author?
    current_account.id == account.id
  end

  def blocked?
    account.blocking?(current_account) || (current_account.domain.present? && account.domain_blocking?(current_account.domain))
  end

  def follower?
    current_account.following?(account)
  end

  def reblogs_may_occur?
    !exclude_reblogs? && !only_media? && !tagged?
  end

  def pinned?
    truthy_param?(:pinned)
  end

  def only_media?
    truthy_param?(:only_media)
  end

  def exclude_replies?
    truthy_param?(:exclude_replies)
  end

  def exclude_reblogs?
    truthy_param?(:exclude_reblogs)
  end

  def tagged?
    params[:tagged].present?
  end

  def truthy_param?(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
