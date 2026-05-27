# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Edge
      module V0
        class HealthsController < Core::Com::BareController
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
