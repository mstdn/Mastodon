# frozen_string_literal: true

require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class FeedsCLI < Thor
    include CLIHelper
    include Redisable

    def self.exit_on_failure?
      true
    end

    option :all, type: :boolean, default: false
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, aliases: [:v]
    option :dry_run, type: :boolean, default: false
    desc 'build [USERNAME]', 'Build home and list feeds for one or all users'
    long_desc <<-LONG_DESC
      Build home and list feeds that are stored in Redis from the database.

      With the --all option, all active users will be processed.
      Otherwise, a single user specified by USERNAME.
    LONG_DESC
    def build(username = nil)
      dry_run = options[:dry_run] ? '(DRY RUN)' : ''

      if options[:all] || username.nil?
        processed, = parallelize_with_progress(Account.joins(:user).merge(User.active)) do |account|
          PrecomputeFeedService.new.call(account) unless options[:dry_run]
        end

        say("Regenerated feeds for #{processed} accounts #{dry_run}", :green, true)
      elsif username.present?
        account = Account.find_local(username)

        if account.nil?
          say('No such account', :red)
          exit(1)
        end

        PrecomputeFeedService.new.call(account) unless options[:dry_run]

        say("OK #{dry_run}", :green, true)
      else
        say('No account(s) given', :red)
        exit(1)
      end
    end

    desc 'clear', 'Remove all home and list feeds from Redis'
    def clear
      keys = redis.keys('feed:*')

      redis.pipelined do
        keys.each { |key| redis.del(key) }
      end

      say('OK', :green)
    end
  end
end
