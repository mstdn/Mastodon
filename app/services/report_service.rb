# frozen_string_literal: true

class ReportService < BaseService
  include Payloadable

  def call(source_account, target_account, options = {})
    @source_account = source_account
    @target_account = target_account
    @status_ids     = options.delete(:status_ids) || []
    @comment        = options.delete(:comment) || ''
    @category       = options.delete(:category) || 'other'
    @rule_ids       = options.delete(:rule_ids)
    @options        = options

    raise ActiveRecord::RecordNotFound if @target_account.suspended?

    create_report!
    notify_staff!
    forward_to_origin! if forward?

    @report
  end

  private

  def create_report!
    @report = @source_account.reports.create!(
      target_account: @target_account,
      status_ids: @status_ids,
      comment: @comment,
      uri: @options[:uri],
      forwarded: forward?,
      category: @category,
      rule_ids: @rule_ids
    )
  end

  def notify_staff!
    return if @report.unresolved_siblings?

    User.staff.includes(:account).each do |u|
      next unless u.allows_report_emails?
      AdminMailer.new_report(u.account, @report).deliver_later
    end
  end

  def forward_to_origin!
    ActivityPub::DeliveryWorker.perform_async(
      payload,
      some_local_account.id,
      @target_account.inbox_url
    )
  end

  def forward?
    !@target_account.local? && ActiveModel::Type::Boolean.new.cast(@options[:forward])
  end

  def payload
    Oj.dump(serialize_payload(@report, ActivityPub::FlagSerializer, account: some_local_account))
  end

  def some_local_account
    @some_local_account ||= Account.representative
  end
end
