require 'rails_helper'

RSpec.describe Admin::DomainBlocksController, type: :controller do
  render_views

  before do
    sign_in Fabricate(:user, role: UserRole.find_by(name: 'Admin')), scope: :user
  end

  describe 'GET #new' do
    it 'assigns a new domain block' do
      get :new

      expect(assigns(:domain_block)).to be_instance_of(DomainBlock)
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST #batch' do
    it 'blocks the domains when succeeded to save' do
      allow(DomainBlockWorker).to receive(:perform_async).and_return(true)

      post :batch, params: {
        save: '',
        form_domain_block_batch: {
          domain_blocks_attributes: {
            '0' => { enabled: '1', domain: 'example.com', severity: 'silence' },
            '1' => { enabled: '0', domain: 'mastodon.social', severity: 'suspend' },
            '2' => { enabled: '1', domain: 'mastodon.online', severity: 'suspend' }
          }
        }
      }

      expect(DomainBlockWorker).to have_received(:perform_async).exactly(2).times
      expect(flash[:notice]).to eq I18n.t('admin.domain_blocks.created_msg')
      expect(response).to redirect_to(admin_instances_path(limited: '1'))
    end
  end

  describe 'POST #create' do
    it 'blocks the domain when succeeded to save' do
      allow(DomainBlockWorker).to receive(:perform_async).and_return(true)

      post :create, params: { domain_block: { domain: 'example.com', severity: 'silence' } }

      expect(DomainBlockWorker).to have_received(:perform_async)
      expect(flash[:notice]).to eq I18n.t('admin.domain_blocks.created_msg')
      expect(response).to redirect_to(admin_instances_path(limited: '1'))
    end

    it 'renders new when failed to save' do
      Fabricate(:domain_block, domain: 'example.com', severity: 'suspend')
      allow(DomainBlockWorker).to receive(:perform_async).and_return(true)

      post :create, params: { domain_block: { domain: 'example.com', severity: 'silence' } }

      expect(DomainBlockWorker).not_to have_received(:perform_async)
      expect(response).to render_template :new
    end

    it 'allows upgrading a block' do
      Fabricate(:domain_block, domain: 'example.com', severity: 'silence')
      allow(DomainBlockWorker).to receive(:perform_async).and_return(true)

      post :create, params: { domain_block: { domain: 'example.com', severity: 'silence', reject_media: true, reject_reports: true } }

      expect(DomainBlockWorker).to have_received(:perform_async)
      expect(flash[:notice]).to eq I18n.t('admin.domain_blocks.created_msg')
      expect(response).to redirect_to(admin_instances_path(limited: '1'))
    end
  end

  describe 'DELETE #destroy' do
    it 'unblocks the domain' do
      service = double(call: true)
      allow(UnblockDomainService).to receive(:new).and_return(service)
      domain_block = Fabricate(:domain_block)
      delete :destroy, params: { id: domain_block.id }

      expect(service).to have_received(:call).with(domain_block)
      expect(flash[:notice]).to eq I18n.t('admin.domain_blocks.destroyed_msg')
      expect(response).to redirect_to(admin_instances_path(limited: '1'))
    end
  end
end
