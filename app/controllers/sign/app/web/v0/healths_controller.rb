# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Web
      module V0
        class HealthsController < Sign::App::BareController
          include ::Health

          AUTHENTICATION_MODE = :bare

          def show
            show_json
          end
        end
      end
    end
  end
end
