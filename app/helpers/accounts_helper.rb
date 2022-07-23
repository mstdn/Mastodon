# frozen_string_literal: true

module AccountsHelper
  def display_name(account, **options)
    str = account.display_name.presence || account.username

    if options[:custom_emojify]
      prerender_custom_emojis(h(str), account.emojis)
    else
      str
    end
  end

  def acct(account)
    if account.local?
      "@#{account.acct}@#{site_hostname}"
    else
      "@#{account.pretty_acct}"
    end
  end

  def account_action_button(account)
    if user_signed_in?
      if account.id == current_user.account_id
        link_to settings_profile_url, class: 'button logo-button' do
          safe_join([logo_as_symbol, t('settings.edit_profile')])
        end
      elsif current_account.following?(account) || current_account.requested?(account)
        link_to account_unfollow_path(account), class: 'button logo-button button--destructive', data: { method: :post } do
          safe_join([logo_as_symbol, t('accounts.unfollow')])
        end
      elsif !(account.memorial? || account.moved?)
        link_to account_follow_path(account), class: "button logo-button#{account.blocking?(current_account) ? ' disabled' : ''}", data: { method: :post } do
          safe_join([logo_as_symbol, t('accounts.follow')])
        end
      end
    elsif !(account.memorial? || account.moved?)
      link_to account_remote_follow_path(account), class: 'button logo-button modal-button', target: '_new' do
        safe_join([logo_as_symbol, t('accounts.follow')])
      end
    end
  end

  def minimal_account_action_button(account)
    if user_signed_in?
      return if account.id == current_user.account_id

      if current_account.following?(account) || current_account.requested?(account)
        link_to account_unfollow_path(account), class: 'icon-button active', data: { method: :post }, title: t('accounts.unfollow') do
          fa_icon('user-times fw')
        end
      elsif !(account.memorial? || account.moved?)
        link_to account_follow_path(account), class: "icon-button#{account.blocking?(current_account) ? ' disabled' : ''}", data: { method: :post }, title: t('accounts.follow') do
          fa_icon('user-plus fw')
        end
      end
    elsif !(account.memorial? || account.moved?)
      link_to account_remote_follow_path(account), class: 'icon-button modal-button', target: '_new', title: t('accounts.follow') do
        fa_icon('user-plus fw')
      end
    end
  end

  def account_badge(account)
    if account.bot?
      content_tag(:div, content_tag(:div, t('accounts.roles.bot'), class: 'account-role bot'), class: 'roles')
    elsif account.group?
      content_tag(:div, content_tag(:div, t('accounts.roles.group'), class: 'account-role group'), class: 'roles')
    elsif account.user_role&.highlighted?
      content_tag(:div, content_tag(:div, account.user_role.name, class: "account-role user-role-#{account.user_role.id}"), class: 'roles')
    end
  end

  def hide_followers_count?(account)
    Setting.hide_followers_count || account.user&.setting_hide_followers_count
  end

  def account_description(account)
    prepend_stats = [
      [
        number_to_human(account.statuses_count, precision: 3, strip_insignificant_zeros: true),
        I18n.t('accounts.posts', count: account.statuses_count),
      ].join(' '),

      [
        number_to_human(account.following_count, precision: 3, strip_insignificant_zeros: true),
        I18n.t('accounts.following', count: account.following_count),
      ].join(' '),
    ]

    unless hide_followers_count?(account)
      prepend_stats << [
        number_to_human(account.followers_count, precision: 3, strip_insignificant_zeros: true),
        I18n.t('accounts.followers', count: account.followers_count),
      ].join(' ')
    end

    [prepend_stats.join(', '), account.note].join(' · ')
  end
end
