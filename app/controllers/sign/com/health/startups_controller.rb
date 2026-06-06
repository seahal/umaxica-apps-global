# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Health
      class StartupsController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::SignCom

        def show
          show_startup
        end
      end
    end
  end
end
