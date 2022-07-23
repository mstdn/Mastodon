# frozen_string_literal: true

module Admin
  class WebhooksController < BaseController
    before_action :set_webhook, except: [:index, :new, :create]

    def index
      authorize :webhook, :index?

      @webhooks = Webhook.page(params[:page])
    end

    def new
      authorize :webhook, :create?

      @webhook = Webhook.new
    end

    def create
      authorize :webhook, :create?

      @webhook = Webhook.new(resource_params)

      if @webhook.save
        redirect_to admin_webhook_path(@webhook)
      else
        render :new
      end
    end

    def show
      authorize @webhook, :show?
    end

    def edit
      authorize @webhook, :update?
    end

    def update
      authorize @webhook, :update?

      if @webhook.update(resource_params)
        redirect_to admin_webhook_path(@webhook)
      else
        render :show
      end
    end

    def enable
      authorize @webhook, :enable?
      @webhook.enable!
      redirect_to admin_webhook_path(@webhook)
    end

    def disable
      authorize @webhook, :disable?
      @webhook.disable!
      redirect_to admin_webhook_path(@webhook)
    end

    def destroy
      authorize @webhook, :destroy?
      @webhook.destroy!
      redirect_to admin_webhooks_path
    end

    private

    def set_webhook
      @webhook = Webhook.find(params[:id])
    end

    def resource_params
      params.require(:webhook).permit(:url, events: [])
    end
  end
end
