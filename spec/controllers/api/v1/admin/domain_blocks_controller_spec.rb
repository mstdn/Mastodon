require 'rails_helper'

RSpec.describe Api::V1::Admin::DomainBlocksController, type: :controller do
  render_views

  let(:role)   { UserRole.find_by(name: 'Admin') }
  let(:user)   { Fabricate(:user, role: role) }
  let(:scopes) { 'admin:read admin:write' }
  let(:token)  { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }

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
    let!(:block) { Fabricate(:domain_block) }

    before do
      get :index
    end

    it_behaves_like 'forbidden for wrong scope', 'write:statuses'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'

    it 'returns http success' do
      expect(response).to have_http_status(200)
    end

    it 'returns the expected domain blocks' do
      json = body_as_json
      expect(json.length).to eq 1
      expect(json[0][:id].to_i).to eq block.id
    end
  end

  describe 'GET #show' do
    let!(:block) { Fabricate(:domain_block) }

    before do
      get :show, params: { id: block.id }
    end

    it_behaves_like 'forbidden for wrong scope', 'write:statuses'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'

    it 'returns http success' do
      expect(response).to have_http_status(200)
    end

    it 'returns expected domain name' do
      json = body_as_json
      expect(json[:domain]).to eq block.domain
    end
  end

  describe 'DELETE #destroy' do
    let!(:block) { Fabricate(:domain_block) }

    before do
      delete :destroy, params: { id: block.id }
    end

    it_behaves_like 'forbidden for wrong scope', 'write:statuses'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'

    it 'returns http success' do
      expect(response).to have_http_status(200)
    end

    it 'deletes the block' do
      expect(DomainBlock.find_by(id: block.id)).to be_nil
    end
  end

  describe 'POST #create' do
    let(:existing_block_domain) { 'example.com' }
    let!(:block) { Fabricate(:domain_block, domain: existing_block_domain, severity: :suspend) }

    before do
      post :create, params: { domain: 'foo.bar.com', severity: :silence }
    end

    it_behaves_like 'forbidden for wrong scope', 'write:statuses'
    it_behaves_like 'forbidden for wrong role', ''
    it_behaves_like 'forbidden for wrong role', 'Moderator'

    it 'returns http success' do
      expect(response).to have_http_status(200)
    end

    it 'returns expected domain name' do
      json = body_as_json
      expect(json[:domain]).to eq 'foo.bar.com'
    end

    it 'creates a domain block' do
      expect(DomainBlock.find_by(domain: 'foo.bar.com')).to_not be_nil
    end

    context 'when a stricter domain block already exists' do
      let(:existing_block_domain) { 'bar.com' }

      it 'returns http unprocessable entity' do
        expect(response).to have_http_status(422)
      end

      it 'renders existing domain block in error' do
        json = body_as_json
        expect(json[:existing_domain_block][:domain]).to eq existing_block_domain
      end
    end
  end
end
