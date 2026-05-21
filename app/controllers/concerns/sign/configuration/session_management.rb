# typed: false
# frozen_string_literal: true

module Sign
  module Configuration
    module SessionManagement
      extend ActiveSupport::Concern

      included do
        before_action :set_session, only: %i(destroy)
      end

      def index
        @sessions = visible_sessions.order(created_at: :desc)

        respond_to do |format|
          format.html
          format.json do
            render json: { sessions: @sessions.map { |session|
              { public_id: session.public_id, created_at: session.created_at }
            } }
          end
        end
      end

      def destroy
        return render_current_session_error if current_session_record?(@session)

        revoke_sessions!([@session], action: "session.revoke")
        render_revoke_success
      end

      def others
        revoke_sessions!(other_active_sessions, action: "session.revoke_others")
        render_revoke_success
      end

      def revoke_all
        return if require_step_up!(scope: "session_revoke_all") == false

        session_count = visible_sessions.count
        Rails.logger.info(LogEvent.format(
          "security.session_revoke_all",
          actor_type: current_resource.class.name,
          actor_id: current_resource.id,
          session_count: session_count,
        ))
        logout_all_sessions_for!(resource: session_owner, reason: revoke_all_reason)
        render_revoke_all_success
      end

      private

      def other_active_sessions
        sessions = visible_sessions
        return sessions if current_session_public_id.blank?

        sessions.reject { |session| current_session_record?(session) }
      end

      def revoke_sessions!(sessions, action:)
        revoked_count = 0
        each_session(sessions) do |session|
          session.revoke!
          revoked_count += 1
        end
        record_session_revoke_activity(action: action, revoked_count: revoked_count)
      end

      def each_session(sessions, &)
        sessions = sessions.includes(session_status_association) if preload_session_status?(sessions)
        return sessions.find_each(&) if sessions.respond_to?(:find_each)

        sessions.each(&)
      end

      def preload_session_status?(sessions)
        sessions.respond_to?(:includes) &&
          sessions.respond_to?(:klass) &&
          sessions.klass.reflect_on_association(session_status_association).present?
      end

      def session_status_association
        :user_token_status
      end

      def record_session_revoke_activity(action:, revoked_count:)
        # Surface controllers may override.
      end

      def set_session
        @session = visible_sessions.find_by(public_id: params[:id])
        return if @session

        head :not_found
        nil
      end

      def current_session_record?(session)
        return false unless session
        return false if current_session_public_id.blank?

        session.public_id == current_session_public_id ||
          (session.respond_to?(:device_session) && session.device_session&.public_id == current_session_public_id)
      end
    end
  end
end
