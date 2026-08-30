# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class ActivitiesController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_activity_log!
        def index
          render inertia: true, props: activities_page_props(activity_log.activities.limit(100))
        rescue ActiveRecord::ActiveRecordError
          render inertia: true, props: activities_page_props(ClientChronicle.none)
        end

        private

        def authorize_activity_log! = authorize!(ClientChronicle, to: :index?)

        def activity_log = @activity_log ||= ::Auth::App::Settings::ActivityLogPresenter.new(current_client)

        def activities_page_props(activities)
          {
            title: t("sign.app.settings.activity.index.page_title"),
            description: t("sign.app.settings.activity.index.description"),
            empty_message: t("sign.app.settings.activity.index.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            table_headings: {
              occurred_at: t("sign.app.settings.activity.index.table.occurred_at"),
              event: t("sign.app.settings.activity.index.table.event"),
              ip_address: t("sign.app.settings.activity.index.table.ip_address"),
              device: "Device",
              login_method: "Login method",
              context: t("sign.app.settings.activity.index.table.context"),
            },
            activities: activities.map { |activity| serialize_activity(activity) },
          }
        end

        def serialize_activity(activity)
          occurred_at = activity_log.occurred_at(activity)

          {
            event_id: activity.event_id,
            occurred_at: occurred_at.present? ? I18n.l(occurred_at, format: :long) : "",
            event_label: activity_log.event_label(activity).to_s,
            ip_address: activity_log.ip_address(activity).to_s,
            user_agent_summary: activity_log.user_agent_summary(activity).to_s,
            login_method: activity_log.login_method(activity).to_s,
            context_text: activity_log.context_text(activity).to_s,
          }
        end
      end
    end
  end
end
