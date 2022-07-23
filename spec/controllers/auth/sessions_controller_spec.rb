# frozen_string_literal: true

require 'rails_helper'
require 'webauthn/fake_client'

RSpec.describe Auth::SessionsController, type: :controller do
  render_views

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(200)
    end
  end

  describe 'DELETE #destroy' do
    let(:user) { Fabricate(:user) }

    context 'with a regular user' do
      it 'redirects to home after sign out' do
        sign_in(user, scope: :user)
        delete :destroy

        expect(response).to redirect_to(new_user_session_path)
      end

      it 'does not delete redirect location with continue=true' do
        sign_in(user, scope: :user)
        controller.store_location_for(:user, '/authorize')
        delete :destroy, params: { continue: 'true' }
        expect(controller.stored_location_for(:user)).to eq '/authorize'
      end
    end

    context 'with a suspended user' do
      before do
        user.account.suspend!
      end

      it 'redirects to home after sign out' do
        sign_in(user, scope: :user)
        delete :destroy

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST #create' do
    context 'using PAM authentication', if: ENV['PAM_ENABLED'] == 'true' do
      context 'using a valid password' do
        before do
          post :create, params: { user: { email: "pam_user1", password: '123456' } }
        end

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end

        it 'logs the user in' do
          expect(controller.current_user).to be_instance_of(User)
        end
      end

      context 'using an invalid password' do
        before do
          post :create, params: { user: { email: "pam_user1", password: 'WRONGPW' } }
        end

        it 'shows a login error' do
          expect(flash[:alert]).to match I18n.t('devise.failure.invalid', authentication_keys: I18n.t('activerecord.attributes.user.email'))
        end

        it "doesn't log the user in" do
          expect(controller.current_user).to be_nil
        end
      end

      context 'using a valid email and existing user' do
        let!(:user) do
          account = Fabricate.build(:account, username: 'pam_user1', user: nil)
          account.save!(validate: false)
          user = Fabricate(:user, email: 'pam@example.com', password: nil, account: account, external: true)
          user
        end

        before do
          post :create, params: { user: { email: user.email, password: '123456' } }
        end

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end

        it 'logs the user in' do
          expect(controller.current_user).to eq user
        end
      end
    end

    context 'using password authentication' do
      let(:user) { Fabricate(:user, email: 'foo@bar.com', password: 'abcdefgh') }

      context 'using a valid password' do
        before do
          post :create, params: { user: { email: user.email, password: user.password } }
        end

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end

        it 'logs the user in' do
          expect(controller.current_user).to eq user
        end
      end

      context 'using a valid password on a previously-used account with a new IP address' do
        let(:previous_ip) { '1.2.3.4' }
        let(:current_ip)  { '4.3.2.1' }

        let!(:previous_login) { Fabricate(:login_activity, user: user, ip: previous_ip) }

        before do
          allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return(current_ip)
          allow(UserMailer).to receive(:suspicious_sign_in).and_return(double('email', 'deliver_later!': nil))
          user.update(current_sign_in_at: 1.month.ago)
          post :create, params: { user: { email: user.email, password: user.password } }
        end

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end

        it 'logs the user in' do
          expect(controller.current_user).to eq user
        end

        it 'sends a suspicious sign-in mail' do
          expect(UserMailer).to have_received(:suspicious_sign_in).with(user, current_ip, anything, anything)
        end
      end

      context 'using email with uppercase letters' do
        before do
          post :create, params: { user: { email: user.email.upcase, password: user.password } }
        end

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end

        it 'logs the user in' do
          expect(controller.current_user).to eq user
        end
      end

      context 'using an invalid password' do
        before do
          post :create, params: { user: { email: user.email, password: 'wrongpw' } }
        end

        it 'shows a login error' do
          expect(flash[:alert]).to match I18n.t('devise.failure.invalid', authentication_keys: I18n.t('activerecord.attributes.user.email'))
        end

        it "doesn't log the user in" do
          expect(controller.current_user).to be_nil
        end
      end

      context 'using an unconfirmed password' do
        before do
          request.headers['Accept-Language'] = accept_language
          post :create, params: { user: { email: unconfirmed_user.email, password: unconfirmed_user.password } }
        end

        let(:unconfirmed_user) { user.tap { |u| u.update!(confirmed_at: nil) } }
        let(:accept_language) { 'fr' }

        it 'redirects to home' do
          expect(response).to redirect_to(root_path)
        end
      end

      context "logging in from the user's page" do
        before do
          allow(controller).to receive(:single_user_mode?).and_return(single_user_mode)
          allow(controller).to receive(:stored_location_for).with(:user).and_return("/@#{user.account.username}")
          post :create, params: { user: { email: user.email, password: user.password } }
        end

        context "in single user mode" do
          let(:single_user_mode) { true }

          it 'redirects to home' do
            expect(response).to redirect_to(root_path)
          end
        end

        context "in non-single user mode" do
          let(:single_user_mode) { false }

          it "redirects back to the user's page" do
            expect(response).to redirect_to(short_account_path(username: user.account))
          end
        end
      end
    end

    context 'using two-factor authentication' do
      context 'with OTP enabled as second factor' do
        let!(:user) do
          Fabricate(:user, email: 'x@y.com', password: 'abcdefgh', otp_required_for_login: true, otp_secret: User.generate_otp_secret(32))
        end

        let!(:recovery_codes) do
          codes = user.generate_otp_backup_codes!
          user.save
          return codes
        end

        context 'using email and password' do
          before do
            post :create, params: { user: { email: user.email, password: user.password } }
          end

          it 'renders two factor authentication page' do
            expect(controller).to render_template("two_factor")
            expect(controller).to render_template(partial: "_otp_authentication_form")
          end
        end

        context 'using email and password after an unfinished log-in attempt to a 2FA-protected account' do
          let!(:other_user) do
            Fabricate(:user, email: 'z@y.com', password: 'abcdefgh', otp_required_for_login: true, otp_secret: User.generate_otp_secret(32))
          end

          before do
            post :create, params: { user: { email: other_user.email, password: other_user.password } }
            post :create, params: { user: { email: user.email, password: user.password } }
          end

          it 'renders two factor authentication page' do
            expect(controller).to render_template("two_factor")
            expect(controller).to render_template(partial: "_otp_authentication_form")
          end
        end

        context 'using upcase email and password' do
          before do
            post :create, params: { user: { email: user.email.upcase, password: user.password } }
          end

          it 'renders two factor authentication page' do
            expect(controller).to render_template("two_factor")
            expect(controller).to render_template(partial: "_otp_authentication_form")
          end
        end

        context 'using a valid OTP' do
          before do
            post :create, params: { user: { otp_attempt: user.current_otp } }, session: { attempt_user_id: user.id, attempt_user_updated_at: user.updated_at.to_s }
          end

          it 'redirects to home' do
            expect(response).to redirect_to(root_path)
          end

          it 'logs the user in' do
            expect(controller.current_user).to eq user
          end
        end

        context 'when the server has an decryption error' do
          before do
            allow_any_instance_of(User).to receive(:validate_and_consume_otp!).and_raise(OpenSSL::Cipher::CipherError)
            post :create, params: { user: { otp_attempt: user.current_otp } }, session: { attempt_user_id: user.id, attempt_user_updated_at: user.updated_at.to_s }
          end

          it 'shows a login error' do
            expect(flash[:alert]).to match I18n.t('users.invalid_otp_token')
          end

          it "doesn't log the user in" do
            expect(controller.current_user).to be_nil
          end
        end

        context 'using a valid recovery code' do
          before do
            post :create, params: { user: { otp_attempt: recovery_codes.first } }, session: { attempt_user_id: user.id, attempt_user_updated_at: user.updated_at.to_s }
          end

          it 'redirects to home' do
            expect(response).to redirect_to(root_path)
          end

          it 'logs the user in' do
            expect(controller.current_user).to eq user
          end
        end

        context 'using an invalid OTP' do
          before do
            post :create, params: { user: { otp_attempt: 'wrongotp' } }, session: { attempt_user_id: user.id, attempt_user_updated_at: user.updated_at.to_s }
          end

          it 'shows a login error' do
            expect(flash[:alert]).to match I18n.t('users.invalid_otp_token')
          end

          it "doesn't log the user in" do
            expect(controller.current_user).to be_nil
          end
        end
      end

      context 'with WebAuthn and OTP enabled as second factor' do
        let!(:user) do
          Fabricate(:user, email: 'x@y.com', password: 'abcdefgh', otp_required_for_login: true, otp_secret: User.generate_otp_secret(32))
        end

        let!(:recovery_codes) do
          codes = user.generate_otp_backup_codes!
          user.save
          return codes
        end

        let!(:webauthn_credential) do
          user.update(webauthn_id: WebAuthn.generate_user_id)
          public_key_credential = WebAuthn::Credential.from_create(fake_client.create)
          user.webauthn_credentials.create(
            nickname: 'SecurityKeyNickname',
            external_id: public_key_credential.id,
            public_key: public_key_credential.public_key,
            sign_count: '1000'
           )
          user.webauthn_credentials.take
        end

        let(:domain) { "#{Rails.configuration.x.use_https ? 'https' : 'http' }://#{Rails.configuration.x.web_domain}" }

        let(:fake_client) { WebAuthn::FakeClient.new(domain) }

        let(:challenge) { WebAuthn::Credential.options_for_get.challenge }

        let(:sign_count) { 1234 }

        let(:fake_credential) { fake_client.get(challenge: challenge, sign_count: sign_count) }

        context 'using email and password' do
          before do
            post :create, params: { user: { email: user.email, password: user.password } }
          end

          it 'renders webauthn authentication page' do
            expect(controller).to render_template("two_factor")
            expect(controller).to render_template(partial: "_webauthn_form")
          end
        end

        context 'using upcase email and password' do
          before do
            post :create, params: { user: { email: user.email.upcase, password: user.password } }
          end

          it 'renders webauthn authentication page' do
            expect(controller).to render_template("two_factor")
            expect(controller).to render_template(partial: "_webauthn_form")
          end
        end

        context 'using a valid webauthn credential' do
          before do
            @controller.session[:webauthn_challenge] = challenge

            post :create, params: { user: { credential: fake_credential } }, session: { attempt_user_id: user.id, attempt_user_updated_at: user.updated_at.to_s }
          end

          it 'instructs the browser to redirect to home' do
            expect(body_as_json[:redirect_path]).to eq(root_path)
          end

          it 'logs the user in' do
            expect(controller.current_user).to eq user
          end

          it 'updates the sign count' do
            expect(webauthn_credential.reload.sign_count).to eq(sign_count)
          end
        end
      end
    end
  end

  describe 'GET #webauthn_options' do
    context 'with WebAuthn and OTP enabled as second factor' do
      let(:domain) { "#{Rails.configuration.x.use_https ? 'https' : 'http' }://#{Rails.configuration.x.web_domain}" }

      let(:fake_client) { WebAuthn::FakeClient.new(domain) }

      let!(:user) do
        Fabricate(:user, email: 'x@y.com', password: 'abcdefgh', otp_required_for_login: true, otp_secret: User.generate_otp_secret(32))
      end

      before do
        user.update(webauthn_id: WebAuthn.generate_user_id)
        public_key_credential = WebAuthn::Credential.from_create(fake_client.create)
        user.webauthn_credentials.create(
          nickname: 'SecurityKeyNickname',
          external_id: public_key_credential.id,
          public_key: public_key_credential.public_key,
          sign_count: '1000'
        )
        post :create, params: { user: { email: user.email, password: user.password } }
      end

      it 'returns http success' do
        get :webauthn_options
        expect(response).to have_http_status :ok
      end
    end
  end
end
