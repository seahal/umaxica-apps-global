# typed: false
# frozen_string_literal: true

module SignVerificationStepUpSessionStore
  extend ActiveSupport::Concern

  private

  def start_step_up_session!(scope:, pt_param:)
    token = current_step_up_token
    raise ActionController::BadRequest, "missing session token" unless token

    safe_path = resolve_step_up_pt(pt_param)
    raise ActionController::BadRequest, "invalid pt" if safe_path.blank?

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
    issue_step_up_ceremony_grant!(token: token, scope: scope_str, return_to: safe_path)
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

  def resolve_step_up_pt(encoded)
    return signed_pt_to_safe_path(encoded) if respond_to?(:signed_pt_to_safe_path, true)
    return safe_internal_path(encoded.to_s) if respond_to?(:safe_internal_path, true)

    encoded.to_s.presence
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

  def issue_step_up_ceremony_grant!(token:, scope:, return_to:)
    return unless respond_to?(:step_up_ceremony_surface, true)

    grant_token = params[:step_up_ceremony_grant].presence
    return validate_acme_step_up_ceremony_grant!(
      grant_token, token: token, scope: scope,
                   return_to: return_to,
    ) if grant_token

    # Compatibility entry only. acme/www owns step-up intent and freshness.
    clear_acme_step_up_completion_state!
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: step_up_ceremony_surface,
      actor_ref: step_up_ceremony_actor_ref,
      session_ref: token.public_id,
      required_scope: scope,
      required_aal: verification_required_aal,
      allowed_methods: available_step_up_methods,
      return_to: return_to,
      expires_at: self.class::STEP_UP_TTL.from_now,
    )
  end

  def validate_acme_step_up_ceremony_grant!(grant_token, token:, scope:, return_to:)
    grant = IdentityStepUpCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id(step_up_ceremony_surface),
    )

    raise ActionController::BadRequest, "grant actor mismatch" unless grant["actor_ref"] == step_up_ceremony_actor_ref
    raise ActionController::BadRequest, "grant session mismatch" unless grant["session_ref"] == token.public_id
    raise ActionController::BadRequest, "grant scope mismatch" unless grant["required_scope"] == scope.to_s
    raise ActionController::BadRequest, "grant return target mismatch" unless grant["return_to"] == return_to

    store_acme_step_up_completion_state!(
      transaction_id: grant["transaction_id"],
      surface: grant["surface"],
    )
    grant
  rescue IdentityStepUpCeremonyContract::Error => e
    raise ActionController::BadRequest, "invalid step-up grant: #{e.message}"
  end

  def acme_step_up_completion_session_key
    :acme_step_up_completion
  end

  def clear_acme_step_up_completion_state!
    return unless request_available_for_step_up_completion_state?

    session.delete(acme_step_up_completion_session_key)
  end

  def store_acme_step_up_completion_state!(transaction_id:, surface:)
    return unless request_available_for_step_up_completion_state?

    session[acme_step_up_completion_session_key] = {
      "transaction_id" => transaction_id,
      "surface" => surface,
      "csrf_token" => params[:step_up_completion_csrf].presence,
    }
  end

  def request_available_for_step_up_completion_state?
    defined?(@_request) && @_request.present?
  end
end
