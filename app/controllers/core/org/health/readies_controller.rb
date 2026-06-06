# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Health
      class ReadiesController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org

        def show
          show_ready
        end
      end
    end
  end
end
