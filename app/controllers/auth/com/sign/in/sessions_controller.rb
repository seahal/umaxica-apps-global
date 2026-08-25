# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class SessionsController < ApplicationController
          include SessionLimitGate
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :deny_all

          # `update` and `destroy` also answer with the session management page, so the component
          # cannot be derived from the action name.
          SESSION_PAGE_COMPONENT = "auth/com/sign/in/sessions/show"

          declare_authentication_mode! :open

          before_action :require_authentication_or_gate

          def show
            load_session_data
            render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
          end

          def update
            @current_visitor = resolve_current_visitor
            return redirect_to_login unless @current_visitor

            ref = params[:ref]

            if ref.present?
              revoke_session_by_ref(@current_visitor, ref)
            else
              refs = Array(params[:revoke_refs]).compact_blank
              if refs.empty?
                load_session_data
                return render inertia: SESSION_PAGE_COMPONENT,
                              props: session_page_props,
                              status: :unprocessable_content
              end

              revoke_sessions_by_refs(@current_visitor, refs)
            end

            if (pending_session_limit_cycle? || current_session_restricted?) && can_promote_session?(@current_visitor)
              if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_visitor)
                consume_session_limit_gate!
                return redirect_to_sign_in_sequence!(
                  pt: retrieve_pt.presence || session_limit_pt,
                )
              end

              promote_current_session!
              consume_session_limit_gate!
              session.delete(:pending_login_visitor_id)
              return redirect_to_return_path
            end

            load_session_data
            render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
          end

          def destroy
            @current_visitor = resolve_current_visitor
            return redirect_to_login unless @current_visitor

            ref = params[:ref]

            if ref.present?
              revoke_session_by_ref(@current_visitor, ref)
              load_session_data
              render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
            else
              current_db_sign_in_flow_for_sequence&.fail_sign_in! if pending_session_limit_cycle?
              consume_session_limit_gate!
              session.delete(:pending_login_visitor_id)

              if current_session&.restricted?
                AuthenticationLogoutCurrentSession.call(
                  resource: @current_visitor,
                  token: current_session,
                  reason: "session_limit_cancelled",
                )
                log_out
              end

              return head :no_content if request.format.json?

              redirect_to(
                auth_com_sign_in_path(ri: current_region_identifier),
                status: :see_other,
              )
            end
          end

          private

          def require_authentication_or_gate
            return if logged_in? && current_session_restricted?
            return if pending_session_limit_cycle?
            return if session_limit_gate_valid? && session[:pending_login_visitor_id].present?

            if logged_in?
              head :forbidden
              return
            end

            redirect_to_login
          end

          def pending_session_limit_cycle?
            current_db_sign_in_flow_for_sequence&.sign_in_session_limit_pending?
          end

          def redirect_to_login
            redirect_to(
              auth_com_sign_in_path(ri: current_region_identifier),
              status: :see_other,
            )
          end

          def authentication_credentials_invalid?
            return false if action_name == "show" && current_session_restricted?

            super
          end

          def redirect_to_return_path
            return_path = retrieve_pt || session_limit_pt
            consume_session_limit_gate!

            if return_path.present?
              destination = path_from_signed_pt(signed_pt_token(return_path)) || base_com_identity_url(
                ri: current_region_identifier,
                host: base_authority_host,
              )
              redirect_to_pt_destination!(destination)
            else
              redirect_to_jump_url(
                base_com_identity_url(ri: current_region_identifier, host: base_authority_host, protocol: "https"),
              )
            end
          end

          def resolve_current_visitor
            return current_resource if current_resource

            visitor_id = session[:pending_login_visitor_id]
            Visitor.find_by(id: visitor_id) if visitor_id
          end

          def load_session_data
            @current_visitor = resolve_current_visitor
            return unless @current_visitor

            @active_sessions = @current_visitor.visitor_tokens.active_status.order(created_at: :desc)
            @restricted_sessions = @current_visitor.visitor_tokens.restricted_status.order(created_at: :desc)
            @current_session_public_id = current_session_public_id
          end

          # The session management page. Every string, timestamp and URL is finished here; the
          # signed ref is the only session identifier that crosses.
          def session_page_props
            active_sessions = @active_sessions.to_a
            restricted_sessions = @restricted_sessions.to_a

            {
              title: I18n.t("sign.app.in.session.title"),
              heading: I18n.t("sign.app.in.session.title"),
              description: I18n.t("sign.app.in.session.description"),
              alert: @session_alert.presence,
              notice: @session_notice.presence,
              restricted_notice:
                current_session_restricted? ? I18n.t("sign.app.in.session.restricted_notice") : nil,
              form: {
                action: auth_com_sign_in_session_path(ri: current_region_identifier),
                submit_label: I18n.t("sign.app.in.session.revoke_selected"),
              },
              cancel: {
                action: auth_com_sign_in_session_path(ri: current_region_identifier),
                label: I18n.t("sign.app.in.session.cancel_logout"),
                confirm: I18n.t("sign.app.in.session.cancel_logout_confirm"),
              },
              active_sessions: active_sessions.any? ? active_sessions_props(active_sessions) : nil,
              restricted_sessions:
                restricted_sessions.any? ? restricted_sessions_props(restricted_sessions) : nil,
            }
          end

          def active_sessions_props(sessions)
            {
              heading: I18n.t("sign.app.in.session.active_sessions"),
              count_label: "(#{sessions.count}/#{VisitorToken::MAX_SESSIONS_PER_VISITOR})",
              revoke_label: I18n.t("sign.app.in.session.revoke"),
              items: sessions.map do |session|
                session_item_props(session, label: I18n.t("sign.app.in.session.session_label"), revocable: true)
              end,
            }
          end

          def restricted_sessions_props(sessions)
            {
              heading: I18n.t("sign.app.in.session.restricted_sessions"),
              items: sessions.map do |session|
                session_item_props(session, label: I18n.t("sign.app.in.session.pending_session"), revocable: false)
              end,
            }
          end

          def session_item_props(session, label:, revocable:)
            current = session.public_id == @current_session_public_id

            {
              label: label,
              current: current,
              current_label: current ? I18n.t("sign.app.in.session.current") : nil,
              created_at_label: I18n.t("sign.app.in.session.created_at"),
              created_at: l(session.created_at, format: :short),
              last_used_at_label: session.last_used_at ? I18n.t("sign.app.in.session.last_used_at") : nil,
              last_used_at: session.last_used_at ? l(session.last_used_at, format: :short) : nil,
              ref: (revocable && !current) ? session.signed_ref : nil,
            }
          end

          def can_promote_session?(visitor)
            active_count =
              ComTicketRecord.connected_to(role: :writing) do
                VisitorToken.active_status.where(visitor_id: visitor.id).count
              end
            active_count < VisitorToken::MAX_SESSIONS_PER_VISITOR
          end

          def promote_current_session!
            return unless current_session&.restricted?

            ComTicketRecord.connected_to(role: :writing) do
              current_session.promote_to_active!
            end
            @current_session = nil
          end

          def revoke_session_by_ref(visitor, ref)
            token = VisitorToken.find_from_signed_ref(ref)
            unless token && allowed_to?(:destroy?, token, context: { user: visitor })
              return
            end

            if token.public_id == current_session_public_id
              return
            end

            AuthenticationSelectedSessionRevoker.call(
              owner: visitor,
              token: token,
              current_token: current_session,
              current_session_public_id: current_session_public_id,
              reason: "session_limit_selected_revoke",
            )
          end

          def revoke_sessions_by_refs(visitor, refs)
            ComTicketRecord.connected_to(role: :writing) do
              VisitorToken.transaction do
                VisitorToken.find_from_signed_refs(refs).each do |token|
                  next unless token && allowed_to?(:destroy?, token, context: { user: visitor })
                  next if token.public_id == current_session_public_id

                  AuthenticationSelectedSessionRevoker.call(
                    owner: visitor,
                    token: token,
                    current_token: current_session,
                    current_session_public_id: current_session_public_id,
                    reason: "session_limit_selected_revoke",
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
