# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Health
      class LivesController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def show
          show_live
        end
      end
    end
  end
end
