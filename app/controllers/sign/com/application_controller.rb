# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::Preference::Global
      include ::Preference::Adoption
      include ::Authentication::Customer
      include ::Authorization::Customer
      include ::Verification::Customer
      include ActionPolicy::Controller
      include Sign::Com::RouteAliasHelper
      include ::CurrentSupport
      include ::Finisher

      helper Sign::Com::ApplicationHelper
      helper_method :current_user if respond_to?(:helper_method)

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
                           ),
                           with: :exception

      guest_only! # FIXME: remove this line.

      before_action :check_default_rate_limit
      before_action :reset_flash
      prepend_before_action :set_preferences_cookie
      prepend_before_action :resolve_param_context
      prepend_before_action :set_region

      prepend_before_action :set_color_theme
      before_action :enforce_required_telephone_registration!
      before_action :enforce_access_policy!
      before_action :enforce_verification_if_required
      before_action :set_current
      before_action :set_current_observability
      after_action :purge_current

      class << self
        def local_prefixes
          prefixes = Array(super)
          app_prefix = controller_path.sub("/com/", "/app/")
          prefixes.include?(app_prefix) ? prefixes : prefixes + [app_prefix]
        end
      end

      private

      def current_user
        current_customer
      end

      def authenticate_user!
        authenticate_customer!
      end

      def actor_staff?
        false
      end

      def current_actor
        current_customer
      end

      def verification_model
        CustomerVerification
      end

      def verification_token_foreign_key
        :customer_token_id
      end

      def identity_email_model
        CustomerEmail
      end

      def identity_telephone_model
        CustomerTelephone
      end

      def identity_from_email_record(record)
        record&.customer
      end

      def identity_from_telephone_record(record)
        record&.customer
      end

      def actor_verification_path(attrs)
        sign_com_verification_path(attrs)
      end

      def verification_redirect_path(rd:, scope_override: nil)
        attrs = { ri: params[:ri], rd: rd }
        scope = scope_override.to_s.presence || verification_scope.to_s.presence
        attrs[:scope] = scope if scope
        sign_com_verification_path(attrs)
      end

      def verification_setup_redirect_path(rd: nil)
        new_sign_com_verification_setup_path(ri: params[:ri], rd: rd || encoded_step_up_rd)
      end

      def after_login_path
        if current_customer&.respond_to?(:verified_telephone?) && !current_customer.verified_telephone?
          return new_sign_com_configuration_telephones_registration_path(ri: params[:ri])
        end

        sign_com_configuration_path
      rescue StandardError
        "/"
      end

      def enforce_required_telephone_registration!
        return unless request.format.html?
        return unless current_customer&.respond_to?(:verified_telephone?)
        return if current_customer.verified_telephone?
        return if telephone_registration_allowed_path?

        redirect_to(
          new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
          notice: t("sign.app.registration.telephone.create.verification_code_sent"),
        )
      end

      def telephone_registration_allowed_path?
        allowed = [
          "sign/com/configuration/telephones/registrations",
          "sign/com/configuration/outs",
        ]
        allowed.include?(controller_path)
      end
    end
  end
end

Sign::Com::ApplicationController.send(:public, :current_user)
