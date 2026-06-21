# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class ActivitiesController < ::Sign::Com::FullAccessController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        helper_method :activity_event_label, :activity_ip_address, :activity_context_text, :activity_occurred_at,
                      :activity_user_agent_summary, :activity_login_method

        def index
          @activities = activity_log.activities.limit(100)
          render "sign/com/settings/activities/index"
        rescue ActiveRecord::ActiveRecordError
          @activities = ClientChronicle.none
          render "sign/com/settings/activities/index"
        end

        def show = index

        private

        def activity_log = @activity_log ||= AcmeComSettingsActivityLog.new(current_visitor)

        def activity_occurred_at(activity) = activity_log.occurred_at(activity)

        def activity_event_label(activity) = activity_log.event_label(activity)

        def activity_ip_address(activity) = activity_log.ip_address(activity)

        def activity_context_text(activity) = activity_log.context_text(activity)

        def activity_user_agent_summary(activity) = activity_log.user_agent_summary(activity)

        def activity_login_method(activity) = activity_log.login_method(activity)
      end
    end
  end
end
