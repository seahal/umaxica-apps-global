# typed: false
# frozen_string_literal: true

module Sign
  module VerificationStepUpLifecycle
    extend ActiveSupport::Concern

    private

    def require_step_up_session!
      return true if valid_step_up_session?(current_step_up_session)
      return true if handle_invalid_step_up_session!

      false
    end

    def consume_step_up_session!(method: nil)
      rs = current_step_up_session
      scope = rs.scope
      method = method.presence || rs.try(:method).presence

      now = Time.current
      ActiveRecord::Base.connected_to(role: :writing) do
        transaction = current_step_up_ceremony_transaction!(scope: scope, now: now)
        result_token = issue_step_up_result!(transaction:, scope:, method:, rs:, now:)
        record_step_up_success!(scope: scope, method: method, now: now)

        clear_step_up_state!
        rs.destroy!
        clear_acme_step_up_completion_state! if respond_to?(:clear_acme_step_up_completion_state!, true)
        return render_acme_step_up_completion!(result_token: result_token, ri: params[:ri])
      end
    end

    def issue_step_up_result!(transaction:, scope:, method:, rs:, now:)
      Identity::StepUpCeremony::ResultIssuer.issue!(
        surface: step_up_ceremony_surface,
        actor_ref: step_up_ceremony_actor_ref,
        session_ref: actor_token.public_id,
        transaction_id: transaction.transaction_id,
        grant_jti: transaction.grant_jti,
        scope: scope,
        aal: "aal2",
        method: method,
        challenge_id: rs.id,
        expires_at: [transaction.expires_at, rs.discarded_at].compact.min,
        attempt_count: rs.attempt_count,
        now: now,
      )
    end

    def record_step_up_success!(scope:, method:, now:)
      actor_token.update!(
        last_step_up_at: now,
        last_step_up_scope: scope,
        last_step_up_aal: "aal2",
        last_step_up_method: method,
        last_step_up_session_public_id: actor_token.public_id,
      )
      create_audit_event!(verification_success_event_id, subject: current_verification_actor)
    end

    def valid_step_up_session?(_session_data)
      raise NotImplementedError, "#{self.class} must define #valid_step_up_session?"
    end

    def handle_invalid_step_up_session!
      raise NotImplementedError, "#{self.class} must define #handle_invalid_step_up_session!"
    end

    def clear_step_up_state!
      raise NotImplementedError, "#{self.class} must define #clear_step_up_state!"
    end

    def record_failed_step_up_attempt!(method)
      step_up_session = current_step_up_session
      if step_up_session.is_a?(Hash)
        step_up_session["attempt_count"] = step_up_session["attempt_count"].to_i + 1
      elsif step_up_session
        step_up_session.with_lock do
          step_up_session.attempt_count = step_up_session.attempt_count.to_i + 1
          step_up_session.save!
        end
      end
      StepUp::CooldownStamp.call(current_verification_actor, method) if current_verification_actor.present?
    end

    def verification_model
      raise NotImplementedError, "#{self.class} must define #verification_model"
    end

    def verification_success_event_id
      raise NotImplementedError, "#{self.class} must define #verification_success_event_id"
    end

    def verification_success_notice_key
      raise NotImplementedError, "#{self.class} must define #verification_success_notice_key"
    end

    def verification_success_fallback_path
      raise NotImplementedError, "#{self.class} must define #verification_success_fallback_path"
    end

    def step_up_ceremony_surface
      case actor_token.class.name
      when "ClientToken" then "app"
      when "VisitorToken" then "com"
      when "OperatorToken" then "org"
      else
        raise NotImplementedError, "unsupported step-up token class: #{actor_token.class.name}"
      end
    end

    def step_up_ceremony_actor_ref
      current_verification_actor.public_id
    end

    def current_step_up_ceremony_transaction!(scope:, now: Time.current)
      transaction =
        Identity::StepUpCeremony::ReplayStore
          .for(step_up_ceremony_surface)
          .latest_pending_for(
            actor_ref: step_up_ceremony_actor_ref,
            session_ref: actor_token.public_id,
            required_scope: scope,
            now: now,
          )
      return transaction if transaction.present?

      # Compatibility for direct sign verification entries until every caller
      # starts through an acme intent route.
      Identity::StepUpCeremony::GrantIssuer.issue!(
        surface: step_up_ceremony_surface,
        actor_ref: step_up_ceremony_actor_ref,
        session_ref: actor_token.public_id,
        required_scope: scope,
        required_aal: verification_required_aal,
        allowed_methods: available_step_up_methods,
        return_to: current_step_up_session&.return_to,
        expires_at: current_step_up_session&.discarded_at,
        now: now,
      ).transaction
    end

    def render_acme_step_up_completion!(result_token:, ri:)
      render(
        "sign/shared/step_up_completion",
        locals: {
          completion_url: acme_step_up_completion_url_for(step_up_ceremony_surface),
          result_token: result_token,
          ri: ri,
          csrf_token: acme_step_up_completion_csrf_token,
        },
      )
    end

    def acme_step_up_completion_state?
      request_available_for_step_up_completion_state? &&
        session[:acme_step_up_completion].to_h["transaction_id"].present?
    end

    def acme_step_up_completion_csrf_token
      session[:acme_step_up_completion].to_h["csrf_token"].presence
    end

    def acme_step_up_completion_url_for(surface)
      case surface.to_s
      when "app"
        completion_acme_app_verification_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
      when "com"
        completion_acme_com_verification_url(host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
      when "org"
        completion_acme_org_verification_url(host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
      else
        raise NotImplementedError, "unsupported step-up surface: #{surface}"
      end
    end
  end
end
