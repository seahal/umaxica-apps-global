# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class ActivitiesController < ::Sign::Com::FullAccessController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!

        def index
          redirect_to(
            acme_com_settings_activities_url(ri: params[:ri], host: acme_authority_host),
            allow_other_host: true,
          )
        end

        def show = index
      end
    end
  end
end
