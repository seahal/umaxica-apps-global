# typed: false
# frozen_string_literal: true

module Authentication
  module SequenceGate
    extend ActiveSupport::Concern

    def sign_in_sequence_redirect_path(pt: nil, default_path: after_dashboard_path)
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        url_pt = signed_pt_token(pt || cycle.return_to)
        return sign_in_session_limit_path(pt: url_pt) if cycle.sign_in_session_limit_pending?
        return sign_in_checkpoint_path(pt: url_pt) if cycle.sign_in_checkpoint_pending?
        return sign_in_selector_path(pt: url_pt) if cycle.sign_in_selector_pending?
        return issue_welcome_gate_and_path(pt: url_pt, sequence_id: cycle.public_id) if cycle.sign_in_completed?
        return reject_invalid_sign_in_sequence_path(default_path) unless cycle.sign_in_guardrail_pending?

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_guardrail_participant(cycle).advance_if_clear!
          end
        return default_path if result.blocking?

        return sign_in_checkpoint_path(pt: url_pt)
      end

      default_path
    end

    def sign_in_session_limit_path(pt: nil)
      attrs = { ri: params[:ri] }
      safe_pt = signed_pt_token(pt)
      attrs[Auth::IoKeys::Params::PT] = safe_pt if safe_pt.present?

      if respond_to?(:sign_app_in_session_path, true)
        sign_app_in_session_path(**attrs)
      elsif respond_to?(:sign_org_in_session_path, true)
        sign_org_in_session_path(**attrs)
      elsif respond_to?(:sign_com_in_session_path, true)
        sign_com_in_session_path(**attrs)
      else
        path = "/in/session"
        query = attrs.compact.to_query
        query.present? ? "#{path}?#{query}" : path
      end
    end

    def reject_invalid_sign_in_sequence_path(default_path)
      default_path
    end

    def redirect_to_sign_in_sequence!(pt: nil, default_path: after_dashboard_path, **redirect_options)
      redirect_to(sign_in_sequence_redirect_path(pt: pt, default_path: default_path), **redirect_options)
    end

    def after_checkpoint_sequence_path(pt: nil, default_path: after_dashboard_path, sequence_id: nil)
      return issue_welcome_gate_and_path(pt: pt, sequence_id: sequence_id) if dashboard_sequence_step_required?

      path_from_signed_pt(signed_pt_token(pt)) || default_path
    end

    def redirect_after_checkpoint_sequence!(pt: nil, default_path: after_dashboard_path, **redirect_options)
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
        return reject_invalid_sign_in_sequence! unless allowed_to?(:complete_checkpoint?, cycle)

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_checkpoint_participant(cycle).advance_if_clear!
          end
        if result.blocking?
          return redirect_to(sign_in_checkpoint_path(pt: cycle.reload.return_to.presence || pt), **redirect_options)
        end

        return redirect_to(
          sign_in_selector_path(pt: cycle.reload.return_to.presence || pt),
          **redirect_options,
        )
      end

      redirect_to(after_checkpoint_sequence_path(pt: pt, default_path: default_path), **redirect_options)
    end

    def continue_checkpoint_sequence_without_content!
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
        return reject_invalid_sign_in_sequence! unless allowed_to?(:show_checkpoint?, cycle)
        return if bulletin_state.present?

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_checkpoint_participant(cycle).advance_if_clear!
          end
        return if result.blocking?

        with_sign_in_cycle_writing(cycle) do
          changes = {
            status_id: cycle.status_id_for("DASHBOARD_PENDING"),
            state: "DASHBOARD_PENDING",
            step: "dashboard",
          }
          changes[:token] =
            current_session if cycle.has_attribute?(:token_id) && cycle.token_id.blank? && current_session
          changes[:session_issued_at] = Time.current if cycle.has_attribute?(:session_issued_at)

          cycle.reload.update!(changes)
        end
        redirect_to(issue_welcome_gate_and_path(pt: cycle.return_to, sequence_id: cycle.public_id))
        return
      end

      if sign_in_sequence_required_for_participant?(:checkpoint)
        return unless require_sign_in_sequence_participant!(
          participant: :checkpoint,
          policy_rule: :show_checkpoint?,
        )
      end

      return if bulletin_state.present?

      redirect_after_checkpoint_sequence!(pt: signed_pt_param)
    end

    # rubocop:disable Metrics/AbcSize
    def continue_welcome_sequence_without_content!
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        process_cycle_based_sequence!(cycle)
      else
        process_non_cycle_sequence!
      end
    end

    def process_cycle_based_sequence!(cycle)
      if cycle.sign_in_completed?
        clear_welcome_gate!
        clear_current_sign_in_cycle_locator!
        return redirect_to(after_welcome_path)
      end
      return redirect_to(sign_in_session_limit_path(pt: cycle.return_to)) if cycle.sign_in_session_limit_pending?
      return redirect_to(sign_in_checkpoint_path(pt: cycle.return_to)) if cycle.sign_in_checkpoint_pending?
      return redirect_to(sign_in_selector_path(pt: cycle.return_to)) if cycle.sign_in_selector_pending?
      return reject_invalid_sign_in_sequence! unless cycle.sign_in_dashboard_pending? || cycle.sign_in_return_pending?
      return redirect_to(after_welcome_path) unless welcome_gate_available?
      return redirect_to(after_welcome_path) unless consume_welcome_gate!(sequence_id: cycle.public_id)

      bind_current_session_to_sign_in_cycle!(cycle)
      return reject_invalid_sign_in_sequence! unless allowed_to?(:show_dashboard?, cycle)

      if cycle.sign_in_dashboard_pending?
        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_dashboard_participant(cycle).advance!
          end
        return if result.blocking?
      end

      reloaded_cycle = cycle.reload
      destination =
        with_sign_in_cycle_writing(reloaded_cycle) do
          SignIn::ReturnParticipant.new(
            cycle: reloaded_cycle,
            default_path: after_welcome_path,
          ).consume!
        end

      clear_welcome_gate!
      clear_current_sign_in_cycle_locator!
      fallback_destination = safe_non_welcome_return_path(after_welcome_path)
      destination = safe_non_welcome_return_path(destination) || fallback_destination
      @welcome_next_path = destination if destination.present?
    end

    def process_non_cycle_sequence!
      return redirect_to(after_welcome_path) unless welcome_gate_available?

      sign_in_sequence_carrier.complete! if sign_in_sequence_carrier.current.participant == "dashboard"
      return redirect_to(after_welcome_path) unless consume_welcome_gate!

      destination = path_from_signed_pt(path_target_value) || after_welcome_path
      clear_welcome_gate!
      sign_in_sequence_carrier.clear!
      @welcome_next_path = destination
      # rubocop:enable Metrics/AbcSize
    end

    alias continue_dashboard_sequence_without_content! continue_welcome_sequence_without_content!

    def continue_selector_sequence!
      cycle = current_db_sign_in_cycle_for_sequence
      return reject_invalid_sign_in_sequence! unless cycle
      return reject_invalid_sign_in_sequence! unless cycle.sign_in_selector_pending?
      return reject_invalid_sign_in_sequence! unless allowed_to?(:show_selector?, cycle)

      with_sign_in_cycle_writing(cycle) do
        SignIn::SelectorParticipant.new(
          cycle: cycle,
          actor: sign_in_cycle_actor(cycle),
          authn_public_id: Actor.authn.login_public_id,
        ).auto_commit_single!
      end

      result = issue_active_session_for_selector!(cycle.reload)
      return reject_invalid_sign_in_sequence! unless result[:status] == :success

      redirect_to(issue_welcome_gate_and_path(pt: cycle.reload.return_to, sequence_id: cycle.public_id))
    rescue SignIn::SelectorParticipant::Error
      reject_invalid_sign_in_sequence!
    end

    def enforce_sign_in_selector_gate!
      return unless logged_in?

      cycle = current_db_sign_in_cycle_for_sequence
      return unless cycle&.sign_in_selector_pending?
      return if sign_in_selector_allowed_request?

      unless request.format.html?
        render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
        return
      end

      redirect_to(sign_in_selector_path(pt: cycle.return_to))
    end

    def dashboard_sequence_step_required?
      true
    end

    def sign_in_sequence_required_for_participant?(_participant)
      true
    end

    def sign_in_sequence_carrier
      @sign_in_sequence_carrier ||= SignIn::SequenceCarrier.new(session, surface: sign_in_sequence_surface)
    end

    def sign_in_sequence_surface
      Actor.tld
    end

    def sign_in_selector_path(pt: nil)
      attrs = { ri: params[:ri] }
      safe_pt = signed_pt_token(pt)
      attrs[Auth::IoKeys::Params::PT] = safe_pt if safe_pt.present?

      if respond_to?(:sign_app_selector_path, true)
        sign_app_selector_path(**attrs)
      elsif respond_to?(:sign_org_selector_path, true)
        sign_org_selector_path(**attrs)
      elsif respond_to?(:sign_com_selector_path, true)
        sign_com_selector_path(**attrs)
      else
        path = "/selector"
        query = attrs.compact.to_query
        query.present? ? "#{path}?#{query}" : path
      end
    end

    def sign_in_selector_allowed_request?
      allowed_paths = [
        sign_in_selector_path,
        sign_in_session_limit_path,
      ]
      allowed_paths.map { |path| URI.parse(path).path }.include?(request.path) ||
        controller_path.end_with?("/outs")
    rescue URI::InvalidURIError
      false
    end

    def welcome_gate_key
      {
        "app" => :app_sign_in_welcome,
        "com" => :com_sign_in_welcome,
        "org" => :org_sign_in_welcome,
      }[sign_in_sequence_surface.to_s] || :sign_in_welcome
    end

    def issue_welcome_gate_and_path(pt:, sequence_id: nil)
      clear_welcome_gate!
      session[welcome_gate_key] = {
        "remaining" => 5,
        "issued_at" => Time.current.to_i,
        "expires_at" => 10.minutes.from_now.to_i,
        "sequence_id" => sequence_id.presence,
      }
      sign_in_welcome_path(pt: pt)
    end

    def clear_welcome_gate!
      session.delete(welcome_gate_key)
    end

    def consume_welcome_gate!(sequence_id: nil)
      gate = session[welcome_gate_key]
      return false unless gate.is_a?(Hash)
      return clear_welcome_gate! && false if welcome_gate_expired?(gate)
      return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
      if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
        return clear_welcome_gate! && false
      end

      remaining = gate["remaining"].to_i - 1
      if remaining <= 0
        clear_welcome_gate!
      else
        session[welcome_gate_key] = gate.merge("remaining" => remaining)
      end
      true
    end

    def welcome_gate_available?(sequence_id: nil)
      gate = session[welcome_gate_key]
      return false unless gate.is_a?(Hash)
      return clear_welcome_gate! && false if welcome_gate_expired?(gate)
      return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
      if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
        return clear_welcome_gate! && false
      end

      true
    end

    def welcome_gate_expired?(gate)
      expires_at = gate["expires_at"].to_i
      expires_at <= 0 || Time.current.to_i >= expires_at
    end

    def begin_sign_in_sequence!(pt:, checkpoint_required:)
      actor = current_resource
      return unless actor

      transition = SignIn::StateMachine.after_session_issued(checkpoint_required: checkpoint_required)
      sequence = sign_in_sequence_carrier.start!(
        surface: Actor.tld,
        actor: actor,
        method: Array(Actor.authn.amr).first || "unknown",
        state: transition.fetch(:state),
        participant: transition.fetch(:participant),
        pt: signed_pt_token(pt),
      )

      SignIn::Result.new(
        status: :success,
        actor: actor,
        token: nil,
        sequence_id: sequence.id,
        redirect_to: nil,
        response_status: :found,
        message: nil,
      )
    end

    def require_sign_in_sequence_participant!(participant:, policy_rule:)
      sequence = sign_in_sequence_carrier.current

      allowed = allowed_to?(policy_rule, sequence, with: SignIn::SequencePolicy)
      return true if allowed

      sign_in_sequence_carrier.expire! if sequence.present? && sequence.expired?
      sign_in_sequence_carrier.fail! if sequence.present? && !sequence.expired?

      Rails.logger.info(
        LogEvent.format(
          "authentication.sign_in_sequence.rejected",
          surface: Actor.tld,
          participant: participant.to_s,
          state: sequence&.state,
          expired: sequence&.expired?,
          actor_type: sequence&.actor_type,
        ),
      )
      render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
      false
    end

    def current_db_sign_in_cycle_for_sequence
      @current_db_sign_in_cycle_for_sequence ||=
        begin
          token = respond_to?(:current_session, true) ? current_session : nil
          SignIn::CycleLocator.new(
            session,
            surface: sign_in_sequence_surface,
            actor: current_resource,
            token: token,
          ).current
        end
    rescue ArgumentError
      nil
    end

    def with_sign_in_cycle_writing(cycle, &)
      cycle.class.connection_class_for_self.connected_to(role: :writing, &)
    end

    def sign_in_checkpoint_participant(cycle)
      SignIn::CheckpointParticipant.new(cycle: cycle, actor: sign_in_cycle_actor(cycle))
    end

    def sign_in_guardrail_participant(cycle)
      SignIn::GuardrailParticipant.new(cycle: cycle, actor: sign_in_cycle_actor(cycle))
    end

    def sign_in_dashboard_participant(cycle)
      SignIn::DashboardParticipant.new(cycle: cycle, actor: current_resource)
    end

    def clear_current_sign_in_cycle_locator!
      sign_in_cycle_locator_for(actor: current_resource, token: current_session).clear!
    rescue ArgumentError
      nil
    end

    def reject_invalid_sign_in_sequence!
      render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
      false
    end

    private

    def start_sign_in_cycle_for!(resource, pt:)
      cycle_class = sign_in_cycle_class_for(resource)
      nonce = SecureRandom.urlsafe_base64(SignIn::CycleLocator::NONCE_BYTES)
      cycle_class.create!(
        principal_id: resource.id,
        status_id: cycle_class.status_id_for("PRIMARY_PENDING"),
        step: "primary",
        return_to: path_from_signed_pt(signed_pt_token(pt)),
        nonce_digest: cycle_class.digest_nonce(nonce),
      )
    end

    def complete_sign_in_cycle_after_session_result!(cycle, resource, result)
      return result unless cycle&.persisted?

      if result[:status] == :session_limit_hard_reject
        cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
        sign_in_cycle_locator_for(actor: resource).issue!(cycle)
        return result
      end

      token = current_session
      return result unless token

      if result[:restricted] || result[:session_management_required]
        cycle.advance_sign_in_to_session_limit! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
        cycle.update!(token: token)
        sign_in_cycle_locator_for(actor: resource, token: token).issue!(cycle)
        reset_current_db_sign_in_cycle_for_sequence!
        return result
      end

      advance_cycle_to_checkpoint_after_active_session!(cycle, resource, token)
      result
    end

    def advance_pending_sign_in_cycle_after_primary!(cycle, resource, result)
      return result unless cycle&.persisted?

      if result[:status] == :session_limit_hard_reject
        cycle.fail_sign_in!
        sign_in_cycle_locator_for(actor: resource).issue!(cycle)
        return result
      end

      if result[:session_management_required]
        cycle.advance_sign_in_to_session_limit! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
        sign_in_cycle_locator_for(actor: resource).issue!(cycle)
        return result
      end

      cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
      if cycle.sign_in_guardrail_pending?
        guardrail = SignIn::GuardrailParticipant.new(cycle: cycle, actor: resource)
        guardrail.advance_if_clear!
      end
      sign_in_cycle_locator_for(actor: resource).issue!(cycle.reload)
      result
    end

    def bind_current_session_to_sign_in_cycle!(cycle)
      return unless cycle.has_attribute?(:token_id)
      return if cycle.token_id.present?
      return unless current_session

      with_sign_in_cycle_writing(cycle) do
        changes = { token: current_session }
        changes[:session_issued_at] = Time.current if cycle.has_attribute?(:session_issued_at)
        cycle.reload.update!(changes)
      end
    end

    def advance_cycle_to_checkpoint_after_active_session!(cycle, resource, token)
      cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?

      if cycle.sign_in_guardrail_pending?
        guardrail = SignIn::GuardrailParticipant.new(cycle: cycle, actor: resource)
        guardrail.advance_if_clear!
      end

      cycle.reload
      cycle.update!(token: token) if cycle.token_id.blank?
      cycle.advance_sign_in_to_checkpoint! if cycle.sign_in_session_issuance_pending?
      sign_in_cycle_locator_for(actor: resource, token: token).issue!(cycle.reload)
      reset_current_db_sign_in_cycle_for_sequence!
    end

    def promote_current_session_limit_cycle!(actor)
      cycle = current_db_sign_in_cycle_for_sequence
      return false unless cycle&.sign_in_session_limit_pending?

      result = SignIn::SessionLimitManager.new(
        cycle: cycle,
        actor: actor,
        token: current_session,
      ).promote!
      cycle = result.cycle.reload
      if cycle.sign_in_guardrail_pending?
        SignIn::GuardrailParticipant.new(cycle: cycle, actor: actor).advance_if_clear!
      end
      true
    end

    def issue_active_session_for_selector!(cycle)
      actor = sign_in_cycle_actor(cycle)
      return { status: :invalid_request } unless actor

      cycle.class.transaction do
        cycle.lock!
        return { status: :success } if cycle.sign_in_completed? && cycle.token_id.present?
        return { status: :invalid_request } unless cycle.sign_in_session_issuance_pending?
      end

      result = log_in(
        actor,
        record_login_audit: true,
        token_kind_id: "BROWSER_WEB",
        require_totp_check: false,
        audit_context: { auth_method: "selector" },
        bootstrap_actor: true,
      )
      return result unless result[:status] == :success

      token = current_session
      cycle.class.transaction do
        cycle.lock!
        return result if cycle.sign_in_completed? && cycle.token_id == token&.id
        return { status: :invalid_request } unless cycle.sign_in_session_issuance_pending?

        changes = { token: token }
        changes[:session_issued_at] = Time.current if cycle.has_attribute?(:session_issued_at)
        cycle.update!(changes)
        cycle.complete_sign_in!
      end
      result
    end

    def sign_in_cycle_actor(cycle)
      return current_resource if current_resource
      return unless cycle.respond_to?(:principal)

      cycle.principal
    end

    def pending_mfa_sign_in_cycle_for(resource)
      sign_in_cycle_locator_for(actor: resource).current
    end

    def sign_in_cycle_locator_for(actor: nil, token: nil)
      SignIn::CycleLocator.new(
        session,
        surface: sign_in_sequence_surface_for_actor(actor),
        actor: actor,
        token: token,
      )
    end

    def sign_in_sequence_surface_for_actor(actor)
      case actor
      when ::Client then :app
      when ::Visitor then :com
      when ::Operator then :org
      else sign_in_sequence_surface
      end
    end

    def sign_in_cycle_class_for(resource)
      case resource
      when ::Client then ClientSignInCycle
      when ::Visitor then VisitorSignInCycle
      when ::Operator then OperatorSignInCycle
      else
        raise ArgumentError, "unsupported sign-in cycle actor"
      end
    end

    def reset_current_db_sign_in_cycle_for_sequence!
      return unless defined?(@current_db_sign_in_cycle_for_sequence)

      remove_instance_variable(:@current_db_sign_in_cycle_for_sequence)
    end

    def establish_sign_in_result!(resource, pt:, ri:, auth_method:, token_kind_id: "BROWSER_WEB",
                                  record_login_audit: true, audit_context: {})
      result = establish_signed_in_session!(
        resource,
        pt: pt,
        ri: ri,
        auth_method: auth_method,
        token_kind_id: token_kind_id,
        record_login_audit: record_login_audit,
        audit_context: audit_context,
      )
      sign_in_result_from_session_result(result, actor: resource)
    end

    def sign_in_result_from_session_result(result, actor: nil, sequence_id: nil)
      SignIn::Result.from_session_result(
        result,
        actor: actor,
        sequence_id: sequence_id,
        session_management_path: session_management_path,
      )
    end
  end
end
