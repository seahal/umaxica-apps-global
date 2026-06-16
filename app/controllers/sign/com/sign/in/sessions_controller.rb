# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module In
        class SessionsController < ApplicationController
          include SessionLimitGate

          AUTHENTICATION_MODE = :deny_all

          declare_authentication_mode! :open

          before_action :require_authentication_or_gate

          def show
            load_session_data
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
                flash[:alert] = I18n.t("sign.app.in.session.no_sessions_selected")
                load_session_data
                return render :show, status: :unprocessable_content
              end

              revoke_sessions_by_refs(@current_visitor, refs)
            end

            if (pending_session_limit_cycle? || current_session_restricted?) && can_promote_session?(@current_visitor)
              if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_visitor)
                consume_session_limit_gate!
                session.delete(:pending_login_visitor_id)
                return redirect_to_sign_in_sequence!(
                  pt: retrieve_pt.presence || session_limit_pt,
                  notice: I18n.t("sign.app.in.session.promoted"),
                )
              end

              promote_current_session!
              consume_session_limit_gate!
              session.delete(:pending_login_visitor_id)
              return redirect_to_return_path(notice: I18n.t("sign.app.in.session.promoted"))
            end

            flash.now[:notice] = I18n.t("sign.app.in.session.sessions_revoked")
            load_session_data
            render :show
          end

          def destroy
            @current_visitor = resolve_current_visitor
            return redirect_to_login unless @current_visitor

            ref = params[:ref]

            if ref.present?
              revoke_session_by_ref(@current_visitor, ref)
              load_session_data
              render :show
            else
              AuthenticationLogoutCurrentSession.call(
                resource: @current_visitor,
                token: current_session,
                reason: "session_limit_cancelled",
              ) if current_session&.restricted?
              current_db_sign_in_flow_for_sequence&.fail_sign_in! if pending_session_limit_cycle?
              consume_session_limit_gate!
              session.delete(:pending_login_visitor_id)
              log_out
              redirect_to(
                sign_com_sign_in_path(ri: params[:ri]),
                notice: I18n.t("sign.app.in.session.cancelled"),
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
              sign_com_sign_in_path(ri: params[:ri]),
              alert: I18n.t("sign.app.in.session.login_required"),
            )
          end

          def redirect_to_return_path(notice:)
            return_path = retrieve_pt || session_limit_pt
            consume_session_limit_gate!

            if return_path.present?
              flash[:notice] = notice
              destination = path_from_signed_pt(signed_pt_token(return_path)) || sign_com_settings_path
              redirect_to_pt_destination!(destination)
            else
              redirect_to(sign_com_settings_path(ri: params[:ri]), notice: notice)
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
              flash[:alert] = I18n.t("sign.app.in.session.invalid_session")
              return
            end

            if token.public_id == current_session_public_id
              flash[:alert] = I18n.t("sign.app.in.session.cannot_revoke_current")
              return
            end

            AuthenticationSelectedSessionRevoker.call(
              owner: visitor,
              token: token,
              current_token: current_session,
              current_session_public_id: current_session_public_id,
              reason: "session_limit_selected_revoke",
            )

            flash.now[:notice] = I18n.t("sign.app.in.session.session_revoked")
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
