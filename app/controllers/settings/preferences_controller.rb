# frozen_string_literal: true

class Settings::PreferencesController < Settings::BaseController
  def show; end

  def update
    user_settings.update(user_settings_params.to_h)

    if current_user.update(user_params)
      I18n.locale = current_user.locale
      redirect_to after_update_redirect_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  private

  def after_update_redirect_path
    settings_preferences_path
  end

  def user_settings
    UserSettingsDecorator.new(current_user)
  end

  def user_params
    params.require(:user).permit(
      :locale,
      chosen_languages: []
    )
  end

  def user_settings_params
    params.require(:user).permit(
      :setting_default_privacy,
      :setting_default_sensitive,
      :setting_default_language,
      :setting_unfollow_modal,
      :setting_boost_modal,
      :setting_favourite_modal,
      :setting_delete_modal,
      :setting_auto_play_gif,
      :setting_display_media,
      :setting_expand_spoilers,
      :setting_reduce_motion,
      :setting_disable_swiping,
      :setting_system_font_ui,
      :setting_system_emoji_font,
      :setting_noindex,
      :setting_hide_followers_count,
      :setting_aggregate_reblogs,
      :setting_show_application,
      :setting_advanced_layout,
      :setting_default_content_type,
      :setting_use_blurhash,
      :setting_use_pending_items,
      :setting_trends,
      :setting_crop_images,
      :setting_always_send_emails,
      notification_emails: %i(follow follow_request reblog favourite mention report pending_account trending_tag trending_link trending_status appeal),
      interactions: %i(must_be_follower must_be_following must_be_following_dm)
    )
  end
end
