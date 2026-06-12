# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module In
        class ChecksController < ::Sign::App::ApplicationController
          include SignAppInCheckControllerSupport
        end
      end
    end
  end
end
