# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Health
      class StartupsController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org

        def show
          show_startup
        end
      end
    end
  end
end
