# typed: false
# frozen_string_literal: true

module Sign
  module VerificationStepUpSessionStore
    extend ActiveSupport::Concern

    private

    def start_step_up_session!(scope:, return_to_param:)
      token = current_step_up_token
      raise ActionController::BadRequest, "missing session token" unless token

      decoded = Base64.urlsafe_decode64(return_to_param.to_s)
      safe_path = safe_internal_path(decoded)
      raise ActionController::BadRequest, "invalid return_to" if safe_path.blank?

      scope_str = scope.to_s
      raise ActionController::BadRequest, "invalid scope" unless self.class::ALLOWED_SCOPES.key?(scope_str)

      pattern = self.class::ALLOWED_SCOPES[scope_str]
      raise ActionController::BadRequest, "scope mismatch" unless safe_path.match?(pattern)

      attrs = {
        step_up_session_token_foreign_key => token.id,
        :scope => scope_str,
        :return_to => safe_path,
        :method => nil,
        :status => "PENDING",
        :attempt_count => 0,
        :verified_at => nil,
        :discarded_at => self.class::STEP_UP_TTL.from_now,
        :purged_at => self.class::STEP_UP_TTL.from_now,
      }
      ActiveRecord::Base.connected_to(role: :writing) do
        step_up_session =
          step_up_session_model.find_or_initialize_by(step_up_session_token_foreign_key => token.id)
        step_up_session.assign_attributes(attrs)
        step_up_session.save!
      end
    rescue ArgumentError
      raise ActionController::BadRequest, "invalid return_to encoding"
    end

    def current_step_up_session
      token = current_step_up_token
      return nil if token.blank?

      ActiveRecord::Base.connected_to(role: :writing) do
        step_up_session_model.find_by(step_up_session_token_foreign_key => token.id)
      end
    end

    def destroy_current_step_up_session!
      ActiveRecord::Base.connected_to(role: :writing) do
        current_step_up_session&.destroy!
      end
    end

    def current_step_up_token
      return actor_token if respond_to?(:actor_token, true) && actor_token.present?

      current_session_token if respond_to?(:current_session_token, true)
    end

    def step_up_session_token_foreign_key
      case step_up_session_model.name
      when "ClientStepUpSession"
        :user_token_id
      when "VisitorStepUpSession"
        :visitor_token_id
      when "OperatorStepUpSession"
        :staff_token_id
      else
        raise(NotImplementedError, "#{self.class} must define #step_up_session_token_foreign_key")
      end
    end
  end
end
