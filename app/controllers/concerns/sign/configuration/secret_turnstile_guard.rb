# typed: false
# frozen_string_literal: true

module Sign
  module Configuration
    module SecretTurnstileGuard
      extend ActiveSupport::Concern

      include ::CloudflareTurnstile

      private

      def verify_secret_turnstile!
        result = cloudflare_turnstile_stealth_validation
        return true if result["success"]

        case action_name
        when "create"
          prepare_secret_turnstile_create_failure
          render :new, status: :unprocessable_content
        when "update"
          @secret.errors.add(:base, t("turnstile_error")) if @secret
          render :edit, status: :unprocessable_content
        when "destroy"
          redirect_to(
            secret_turnstile_failure_redirect_path,
            alert: t("turnstile_error"),
            status: :see_other,
          )
        else
          render plain: t("turnstile_error"), status: :unprocessable_content
        end

        false
      end

      def prepare_secret_turnstile_create_failure
        raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
      end

      def secret_turnstile_failure_redirect_path
        raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
      end
    end
  end
end
