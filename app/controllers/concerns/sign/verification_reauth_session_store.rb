# typed: false
# frozen_string_literal: true

module Sign
  module VerificationReauthSessionStore
    extend ActiveSupport::Concern

    private

    def start_reauth_session!(scope:, return_to_param:)
      token = current_reauth_token
      raise ActionController::BadRequest, "missing session token" unless token

      decoded = Base64.urlsafe_decode64(return_to_param.to_s)
      safe_path = safe_internal_path(decoded)
      raise ActionController::BadRequest, "invalid return_to" if safe_path.blank?

      scope_str = scope.to_s
      raise ActionController::BadRequest, "invalid scope" unless self.class::ALLOWED_SCOPES.key?(scope_str)

      pattern = self.class::ALLOWED_SCOPES[scope_str]
      raise ActionController::BadRequest, "scope mismatch" unless safe_path.match?(pattern)

      attrs = {
        reauth_session_token_foreign_key => token.id,
        :scope => scope_str,
        :return_to => safe_path,
        :method => nil,
        :status => "PENDING",
        :attempt_count => 0,
        :verified_at => nil,
        :lapses_at => self.class::REAUTH_TTL.from_now,
        :purge_at => self.class::REAUTH_TTL.from_now,
      }
      ActiveRecord::Base.connected_to(role: :writing) do
        reauth_session_model.upsert(
          attrs,
          unique_by: "index_#{reauth_session_model.table_name}_on_#{reauth_session_token_foreign_key}",
        )
      end
    rescue ArgumentError
      raise ActionController::BadRequest, "invalid return_to encoding"
    end

    def current_reauth_session
      token = current_reauth_token
      return nil if token.blank?

      ActiveRecord::Base.connected_to(role: :writing) do
        reauth_session_model.find_by(reauth_session_token_foreign_key => token.id)
      end
    end

    def destroy_current_reauth_session!
      ActiveRecord::Base.connected_to(role: :writing) do
        current_reauth_session&.destroy!
      end
    end

    def current_reauth_token
      return actor_token if respond_to?(:actor_token, true) && actor_token.present?

      current_session_token if respond_to?(:current_session_token, true)
    end

    def reauth_session_token_foreign_key
      case reauth_session_model.name
      when "UserReauthSession"
        :user_token_id
      when "VisitorReauthSession"
        :visitor_token_id
      when "OperatorReauthSession"
        :staff_token_id
      else
        raise(NotImplementedError, "#{self.class} must define #reauth_session_token_foreign_key")
      end
    end
  end
end
