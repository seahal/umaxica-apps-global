# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class ActivitiesController < ::Sign::App::ApplicationController
        include ::SignSettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
      end
    end
  end
end
