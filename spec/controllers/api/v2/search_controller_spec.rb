# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V2::SearchController, type: :controller do
  render_views

  let(:user)  { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read:search') }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { q: 'test' }

      expect(response).to have_http_status(200)
    end
  end
end
