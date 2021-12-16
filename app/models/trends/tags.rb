# frozen_string_literal: true

class Trends::Tags < Trends::Base
  PREFIX = 'trending_tags'

  self.default_options = {
    threshold: 5,
    review_threshold: 10,
    max_score_cooldown: 2.days.freeze,
    max_score_halflife: 4.hours.freeze,
  }

  def register(status, at_time = Time.now.utc)
    original_status = status.reblog? ? status.reblog : status

    return unless original_status.public_visibility? && status.public_visibility? &&
                  !original_status.account.silenced? && !status.account.silenced?

    original_status.tags.each do |tag|
      add(tag, status.account_id, at_time) if tag.usable?
    end
  end

  def add(tag, account_id, at_time = Time.now.utc)
    tag.history.add(account_id, at_time)
    record_used_id(tag.id, at_time)
  end

  def refresh(at_time = Time.now.utc)
    tags = Tag.where(id: (recently_used_ids(at_time) + currently_trending_ids(false, -1)).uniq)
    calculate_scores(tags, at_time)
    trim_older_items
  end

  def get(allowed, limit)
    tag_ids = currently_trending_ids(allowed, limit)
    tags = Tag.where(id: tag_ids).index_by(&:id)
    tag_ids.map { |id| tags[id] }.compact
  end

  def request_review
    tags = Tag.where(id: currently_trending_ids(false, -1))

    tags_requiring_review = tags.filter_map do |tag|
      next unless would_be_trending?(tag.id) && !tag.trendable? && tag.requires_review_notification?

      tag.touch(:requested_review_at)
      tag
    end

    return if tags_requiring_review.empty?

    User.staff.includes(:account).find_each do |user|
      AdminMailer.new_trending_tags(user.account, tags_requiring_review).deliver_later! if user.allows_trending_tag_emails?
    end
  end

  protected

  def key_prefix
    PREFIX
  end

  private

  def calculate_scores(tags, at_time)
    tags.each do |tag|
      expected  = tag.history.get(at_time - 1.day).accounts.to_f
      expected  = 1.0 if expected.zero?
      observed  = tag.history.get(at_time).accounts.to_f
      max_time  = tag.max_score_at
      max_score = tag.max_score
      max_score = 0 if max_time.nil? || max_time < (at_time - options[:max_score_cooldown])

      score = begin
        if expected > observed || observed < options[:threshold]
          0
        else
          ((observed - expected)**2) / expected
        end
      end

      if score > max_score
        max_score = score
        max_time  = at_time

        # Not interested in triggering any callbacks for this
        tag.update_columns(max_score: max_score, max_score_at: max_time)
      end

      decaying_score = max_score * (0.5**((at_time.to_f - max_time.to_f) / options[:max_score_halflife].to_f))

      if decaying_score.zero?
        redis.zrem("#{PREFIX}:all", tag.id)
        redis.zrem("#{PREFIX}:allowed", tag.id)
      else
        redis.zadd("#{PREFIX}:all", decaying_score, tag.id)

        if tag.trendable?
          redis.zadd("#{PREFIX}:allowed", decaying_score, tag.id)
        else
          redis.zrem("#{PREFIX}:allowed", tag.id)
        end
      end
    end
  end

  def would_be_trending?(id)
    score(id) > score_at_rank(options[:review_threshold] - 1)
  end
end
