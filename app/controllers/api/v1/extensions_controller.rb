# frozen_string_literal: true
require 'mastodon/extension'

class Api::V1::ExtensionsController < Api::BaseController
  def index
    render json: Mastodon::Extension.all
  end
end
