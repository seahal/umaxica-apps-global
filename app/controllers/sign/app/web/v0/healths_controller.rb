# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Web
      module V0
        class HealthsController < Sign::App::BareController
          AUTHENTICATION_MODE = :bare

          include ::Health

          def show
            show_json
          end
        end
      end
    end
  end
end
