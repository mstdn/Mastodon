# frozen_string_literal: true

module Glitch
  class ApplyKeywordMutesWorker
    include Sidekiq::Worker

    sidekiq_options unique: :until_executed

    def perform(account_id)
      Glitch::ApplyKeywordMutesService.new.call(Account.find(account_id))
    end
  end
end
