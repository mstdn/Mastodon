# frozen_string_literal: true

class AboutController < ApplicationController
  include RegistrationSpamConcern

  before_action :set_pack

  layout 'public'

  before_action :require_open_federation!, only: [:show, :more]
  before_action :set_body_classes, only: :show
  before_action :set_instance_presenter
  before_action :set_expires_in, only: [:more]
  before_action :set_registration_form_time, only: :show

  skip_before_action :require_functional!, only: [:more]

  def show; end

  def more
    flash.now[:notice] = I18n.t('about.instance_actor_flash') if params[:instance_actor]

    toc_generator = TOCGenerator.new(@instance_presenter.extended_description)

    @rules             = Rule.ordered
    @contents          = toc_generator.html
    @table_of_contents = toc_generator.toc
    @blocks            = DomainBlock.with_user_facing_limitations.by_severity if display_blocks?
  end

  helper_method :display_blocks?
  helper_method :display_blocks_rationale?
  helper_method :public_fetch_mode?
  helper_method :new_user

  private

  def require_open_federation!
    not_found if whitelist_mode?
  end

  def display_blocks?
    Setting.show_domain_blocks == 'all' || (Setting.show_domain_blocks == 'users' && user_signed_in?)
  end

  def display_blocks_rationale?
    Setting.show_domain_blocks_rationale == 'all' || (Setting.show_domain_blocks_rationale == 'users' && user_signed_in?)
  end

  def new_user
    User.new.tap do |user|
      user.build_account
      user.build_invite_request
    end
  end

  def set_pack
    use_pack 'public'
  end

  def set_instance_presenter
    @instance_presenter = InstancePresenter.new
  end

  def set_body_classes
    @hide_navbar = true
  end

  def set_expires_in
    expires_in 0, public: true
  end
end
