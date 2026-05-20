# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Edge
      module V0
        class HealthsController < Sign::Org::BareController
          include ::Health

          def show
            show_json
          end
        end
      end
    end
  end
end
