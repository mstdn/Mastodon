require 'rails_helper'

describe Admin::ResetsController do
  render_views

  let(:account) { Fabricate(:account) }
  before do
    sign_in Fabricate(:user, role: UserRole.find_by(name: 'Admin')), scope: :user
  end

  describe 'POST #create' do
    it 'redirects to admin accounts page' do
      expect_any_instance_of(User).to receive(:send_reset_password_instructions) do |value|
        expect(value.account_id).to eq account.id
      end

      post :create, params: { account_id: account.id }

      expect(response).to redirect_to(admin_account_path(account.id))
    end
  end
end
