# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Api
      module V0
        # This API base is self-contained because the Core browser API must not
        # inherit HTML callbacks that write unrelated cookies.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          include ::CoreBrowserApiBoundary

          private

          def core_actor_tld = :com

          def core_resource_class = ::Visitor

          def core_token_class = ::VisitorToken

          def core_resource_type = "visitor"
        end
      end
    end
  end
end
