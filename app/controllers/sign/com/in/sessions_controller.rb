# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class SessionsController < ApplicationController
        include SessionLimitGate

        public_strict!

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

          if current_session_restricted? && can_promote_session?(@current_visitor)
            if promote_current_session_limit_cycle!(@current_visitor)
              consume_session_limit_gate!
              session.delete(:pending_login_visitor_id)
              return redirect_to_sign_in_sequence!(
                rt: retrieve_redirect_parameter.presence || session_limit_return_to,
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
            current_session.revoke! if current_session&.restricted?
            consume_session_limit_gate!
            session.delete(:pending_login_visitor_id)
            log_out
            redirect_to(new_sign_com_in_path(ri: params[:ri]), notice: I18n.t("sign.app.in.session.cancelled"))
          end
        end

        private

        def require_authentication_or_gate
          return if logged_in? && current_session_restricted?
          return if session_limit_gate_valid? && session[:pending_login_visitor_id].present?

          if logged_in?
            head :forbidden
            return
          end

          redirect_to_login
        end

        def redirect_to_login
          redirect_to(new_sign_com_in_path(ri: params[:ri]), alert: I18n.t("sign.app.in.session.login_required"))
        end

        def redirect_to_return_path(notice:)
          return_path = retrieve_redirect_parameter || session_limit_return_to
          consume_session_limit_gate!

          if return_path.present?
            flash[:notice] = notice
            jump_to_generated_url(return_path, fallback: sign_com_configuration_path)
          else
            redirect_to(sign_com_configuration_path(ri: params[:ri]), notice: notice)
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
            OrgTicketRecord.connected_to(role: :writing) do
              VisitorToken.active_status.where(visitor_id: visitor.id).count
            end
          active_count < VisitorToken::MAX_SESSIONS_PER_VISITOR
        end

        def promote_current_session!
          return unless current_session&.restricted?

          OrgTicketRecord.connected_to(role: :writing) do
            current_session.promote_to_active!
          end
          @current_session = nil
        end

        def revoke_session_by_ref(visitor, ref)
          token = VisitorToken.find_from_signed_ref(ref)
          unless token && token.visitor_id == visitor.id
            flash[:alert] = I18n.t("sign.app.in.session.invalid_session")
            return
          end

          if token.public_id == current_session_public_id
            flash[:alert] = I18n.t("sign.app.in.session.cannot_revoke_current")
            return
          end

          OrgTicketRecord.connected_to(role: :writing) do
            token.revoke!
          end

          flash.now[:notice] = I18n.t("sign.app.in.session.session_revoked")
        end

        def revoke_sessions_by_refs(visitor, refs)
          OrgTicketRecord.connected_to(role: :writing) do
            VisitorToken.transaction do
              VisitorToken.find_from_signed_refs(refs).each do |token|
                next unless token && token.visitor_id == visitor.id
                next if token.public_id == current_session_public_id

                token.revoke!
              end
            end
          end
        end
      end
    end
  end
end
