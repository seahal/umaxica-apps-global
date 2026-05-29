# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Edge
      module V0
        class HealthsController < Acme::Org::BareController
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
