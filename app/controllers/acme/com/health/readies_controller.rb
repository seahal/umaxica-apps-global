# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Health
      class ReadiesController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def show
          show_ready
        end
      end
    end
  end
end
