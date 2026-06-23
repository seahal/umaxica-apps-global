# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class SessionsController < ::Sign::Com::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :set_session, only: %i(show destroy)

        helper_method :current_session_record?

        def index
          @sessions = visible_sessions.order(created_at: :desc)
        end

        def show
          render :show
        end

        def destroy
          @session.revoke! unless current_session_record?(@session)
          redirect_to(sign_com_settings_sessions_path(ri: params[:ri]), status: :see_other)
        end

        def others
          visible_sessions.find_each do |token|
            token.revoke! unless current_session_record?(token)
          end
          redirect_to(sign_com_settings_sessions_path(ri: params[:ri]), status: :see_other)
        end

        def revoke_all
          visible_sessions.find_each(&:revoke!)
          redirect_to(sign_com_sign_out_path(ri: params[:ri]), status: :see_other)
        end

        private

        def visible_sessions
          current_visitor.visitor_tokens.session_inventory
        end

        def set_session
          @session = visible_sessions.find_by!(public_id: params.expect(:id))
        end

        def current_session_record?(session)
          session&.public_id == current_session_public_id
        end
      end
    end
  end
end
