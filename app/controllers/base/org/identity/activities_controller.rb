# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class ActivitiesController < ::Base::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :authorize_activity_log!, only: %i(index)

        def index
          @activities = activity_log.activities.limit(100)
          render inertia: "base/org/identity/activities/index", props: index_page_props
        rescue ActiveRecord::ActiveRecordError
          @activities = OperatorChronicle.none
          render inertia: "base/org/identity/activities/index", props: index_page_props
        end

        private

        def authorize_activity_log!
          authorize!(OperatorChronicle, to: :index?)
        end

        def index_page_props
          {
            title: t("sign.org.settings.activity.index.page_title"),
            description: t("sign.org.settings.activity.index.description"),
            empty_message: t("sign.org.settings.activity.index.empty"),
            back_link: {
              label: t("sign.org.settings.show.back"),
              href: base_org_identity_path(ri: params[:ri]),
            },
            columns: {
              occurred_at: t("sign.org.settings.activity.index.table.occurred_at"),
              event: t("sign.org.settings.activity.index.table.event"),
              ip_address: t("sign.org.settings.activity.index.table.ip_address"),
              device: "Device",
              login_method: "Login method",
              context: t("sign.org.settings.activity.index.table.context"),
            },
            activities: @activities.map { |activity| serialize_activity(activity) },
          }
        end

        def serialize_activity(activity)
          {
            id: activity.id.to_s,
            occurred_at: l(activity_log.occurred_at(activity), format: :long),
            event_label: activity_log.event_label(activity),
            event_id: activity.event_id,
            ip_address: activity_log.ip_address(activity),
            device: activity_log.user_agent_summary(activity),
            login_method: activity_log.login_method(activity),
            context: activity_log.context_text(activity),
          }
        end

        def activity_log = @activity_log ||= ::Base::Org::Identity::ActivityLog.new(current_operator)
      end
    end
  end
end
