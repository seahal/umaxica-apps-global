# typed: false
# frozen_string_literal: true

module Sign
  module PromotionalEmailUnsubscribeActions
    extend ActiveSupport::Concern
    include ::CloudflareTurnstile

    included do
      before_action :set_promotional_email
    end

    def edit
    end

    def destroy
      return unless verified_turnstile_for_destroy?

      unsubscribe_promotional_email!
      redirect_to(redirect_after_unsubscribe_path(token: params[:token]))
    end

    def create
      unsubscribe_promotional_email!
      head :ok
    end

    private

    def verified_turnstile_for_destroy?
      return true if cloudflare_turnstile_validation["success"]

      redirect_to(
        redirect_after_unsubscribe_path(token: params[:token]),
        alert: t("turnstile_error"),
        status: :see_other,
      )
      false
    end

    def verified_request?
      super || promotional_unsubscribe_create_request?
    end

    def promotional_unsubscribe_create_request?
      return false unless action_name == "create"

      email = promotional_email_model.find_by(public_id: params[:id])
      return false unless email

      PromotionalEmailUnsubscribeToken.valid?(email, params[:token], scope: promotional_email_scope)
    end

    def set_promotional_email
      @email = promotional_email_model.find_by(public_id: params[:id])
      return head :not_found unless @email
      return if PromotionalEmailUnsubscribeToken.valid?(@email, params[:token], scope: promotional_email_scope)

      head :not_found
    end

    def unsubscribe_promotional_email!
      @email.unsubscribe_promotional!
    end
  end
end
