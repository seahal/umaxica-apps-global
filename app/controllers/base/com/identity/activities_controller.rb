# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class ActivitiesController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def index
          @activities = activity_log.activities.limit(100)
          render inertia: "base/com/identity/activities/index", props: index_page_props
        rescue ActiveRecord::ActiveRecordError
          @activities = ClientChronicle.none
          render inertia: "base/com/identity/activities/index", props: index_page_props
        end

        def show = index

        private

        def index_page_props
          {
            title: t("sign.app.settings.activity.index.page_title"),
            description: t("sign.app.settings.activity.index.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_com_identity_path(ri: params[:ri]),
            },
            empty_message: t("sign.app.settings.activity.index.empty"),
            columns: {
              occurred_at: t("sign.app.settings.activity.index.table.occurred_at"),
              event: t("sign.app.settings.activity.index.table.event"),
              ip_address: t("sign.app.settings.activity.index.table.ip_address"),
              device: "Device",
              login_method: "Login method",
              context: t("sign.app.settings.activity.index.table.context"),
            },
            activities: @activities.map { |activity| serialize_activity(activity) },
          }
        end

        # Every cell is finished text: the ERB called these helpers, and the props boundary is where
        # that formatting now lives. `event_id` names a chronicle event, not a credential.
        def serialize_activity(activity)
          {
            id: activity.id.to_s,
            occurred_at: l(activity_occurred_at(activity), format: :long),
            event_label: activity_event_label(activity),
            event_id: activity.event_id.to_s,
            ip_address: activity_ip_address(activity),
            device: activity_user_agent_summary(activity),
            login_method: activity_login_method(activity),
            context: activity_context_text(activity),
          }
        end

        def activity_log = @activity_log ||= ::Base::Com::Identity::ActivityLogPresenter.new(current_visitor)

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
