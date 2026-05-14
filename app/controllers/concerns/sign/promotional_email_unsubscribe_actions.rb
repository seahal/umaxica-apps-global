# typed: false
# frozen_string_literal: true

module Sign
  module PromotionalEmailUnsubscribeActions
    extend ActiveSupport::Concern

    included do
      public_strict!
      protect_from_forgery with: :null_session, only: :create
      before_action :set_promotional_email
    end

    def edit
    end

    def destroy
      unsubscribe_promotional_email!
      redirect_to(redirect_after_unsubscribe_path(token: params[:token]))
    end

    def create
      unsubscribe_promotional_email!
      head :ok
    end

    private

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
