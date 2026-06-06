# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Health
      class StartupsController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def show
          show_startup
        end
      end
    end
  end
end
