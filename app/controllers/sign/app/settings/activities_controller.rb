# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ActivitiesController < ::Sign::App::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_activity_log!, only: %i(index show)
        helper_method :activity_event_label, :activity_ip_address, :activity_context_text, :activity_occurred_at,
                      :activity_user_agent_summary, :activity_login_method

        def index = redirect_to(acme_app_identity_activities_path(ri: params[:ri]), status: :see_other)

        def show = redirect_to(acme_app_identity_activities_path(ri: params[:ri]), status: :see_other)

        private

        def authorize_activity_log! = authorize!(ClientChronicle, to: :index?)
      end
    end
  end
end
