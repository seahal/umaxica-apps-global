# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Api
      module V0
        # This API base is self-contained because the Core browser API must not
        # inherit HTML callbacks that write unrelated cookies.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          include ::CoreBrowserApiBoundary

          private

          def core_actor_tld = :org

          def core_resource_class = ::Operator

          def core_token_class = ::OperatorToken

          def core_resource_type = "operator"
        end
      end
    end
  end
end
