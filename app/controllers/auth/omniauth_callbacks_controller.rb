# frozen_string_literal: true

class Auth::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token

  def self.provides_callback_for(provider)
    provider_id = provider.to_s.chomp '_oauth2'

    define_method provider do
      @user = User.find_for_oauth(request.env['omniauth.auth'], current_user)

      if @user.persisted?
        LoginActivity.create(
          user: @user,
          success: true,
          authentication_method: :omniauth,
          provider: provider,
          ip: request.remote_ip,
          user_agent: request.user_agent
        )

        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: provider_id.capitalize) if is_navigational_format?
      else
        session["devise.#{provider}_data"] = request.env['omniauth.auth']
        redirect_to new_user_registration_url
      end
    end
  end

  Devise.omniauth_configs.each_key do |provider|
    provides_callback_for provider
  end

  def after_sign_in_path_for(resource)
    if resource.email_verified?
      root_path
    else
      auth_setup_path(missing_email: '1')
    end
  end
end
