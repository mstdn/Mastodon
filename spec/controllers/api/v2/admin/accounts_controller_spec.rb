require 'rails_helper'

RSpec.describe Api::V2::Admin::AccountsController, type: :controller do
  render_views

  let(:role)   { UserRole.find_by(name: 'Moderator') }
  let(:user)   { Fabricate(:user, role: role) }
  let(:scopes) { 'admin:read admin:write' }
  let(:token)  { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:account) { Fabricate(:account) }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  shared_examples 'forbidden for wrong scope' do |wrong_scope|
    let(:scopes) { wrong_scope }

    it 'returns http forbidden' do
      expect(response).to have_http_status(403)
    end
  end

  shared_examples 'forbidden for wrong role' do |wrong_role|
    let(:role) { UserRole.find_by(name: wrong_role) }

    it 'returns http forbidden' do
      expect(response).to have_http_status(403)
    end
  end

  describe 'GET #index' do
    let!(:remote_account)       { Fabricate(:account, domain: 'example.org') }
    let!(:other_remote_account) { Fabricate(:account, domain: 'foo.bar') }
    let!(:suspended_account)    { Fabricate(:account, suspended: true) }
    let!(:suspended_remote)     { Fabricate(:account, domain: 'foo.bar', suspended: true) }
    let!(:disabled_account)     { Fabricate(:user, disabled: true).account }
    let!(:pending_account)      { Fabricate(:user, approved: false).account }
    let!(:admin_account)        { user.account }

    let(:params) { {} }

    before do
      pending_account.user.update(approved: false)
      get :index, params: params
    end

    it_behaves_like 'forbidden for wrong scope', 'write:statuses'
    it_behaves_like 'forbidden for wrong role', ''

    [
      [{ status: 'active', origin: 'local', permissions: 'staff' }, [:admin_account]],
      [{ by_domain: 'example.org', origin: 'remote' }, [:remote_account]],
      [{ status: 'suspended' }, [:suspended_remote, :suspended_account]],
      [{ status: 'disabled' }, [:disabled_account]],
      [{ status: 'pending' }, [:pending_account]],
    ].each do |params, expected_results|
      context "when called with #{params.inspect}" do
        let(:params) { params }

        it 'returns http success' do
          expect(response).to have_http_status(200)
        end

        it "returns the correct accounts (#{expected_results.inspect})" do
          json = body_as_json

          expect(json.map { |a| a[:id].to_i }).to eq (expected_results.map { |symbol| send(symbol).id })
        end
      end
    end
  end
end
