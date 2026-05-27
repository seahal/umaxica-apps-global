# typed: false
# frozen_string_literal: true

module Core
  module App
    module Edge
      module V0
        class HealthsController < Core::App::BareController
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
