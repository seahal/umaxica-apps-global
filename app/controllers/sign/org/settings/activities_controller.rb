# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class ActivitiesController < ::Sign::Org::ApplicationController
        include ::SignSettingsAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
      end
    end
  end
end
