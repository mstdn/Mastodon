# frozen_string_literal: true

class DistributionWorker
  include Sidekiq::Worker
  include Redisable

  def perform(status_id, options = {})
    RedisLock.acquire(redis: redis, key: "distribute:#{status_id}", autorelease: 5.minutes.seconds) do |lock|
      if lock.acquired?
        FanOutOnWriteService.new.call(Status.find(status_id), **options.symbolize_keys)
      else
        raise Mastodon::RaceConditionError
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
