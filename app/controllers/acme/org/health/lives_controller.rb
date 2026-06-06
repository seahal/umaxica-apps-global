# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Health
      class LivesController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org

        def show
          show_live
        end
      end
    end
  end
end
