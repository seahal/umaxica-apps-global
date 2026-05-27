# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Edge
      module V0
        class HealthsController < Core::Org::BareController
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
