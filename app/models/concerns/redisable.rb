# frozen_string_literal: true

module Redisable
  def redis
    Thread.current[:redis] ||= RedisConfiguration.pool.checkout
  end

  def with_redis(&block)
    RedisConfiguration.with(&block)
  end
end
