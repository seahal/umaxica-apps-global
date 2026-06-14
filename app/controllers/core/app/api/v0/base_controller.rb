# typed: false
# frozen_string_literal: true

module Core
  module App
    module Api
      module V0
        # This API base is self-contained because the Core browser API must not
        # inherit HTML callbacks that write unrelated cookies.
        class BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
          include ::CoreBrowserApiBoundary

          private

          def core_actor_tld = :app

          def core_resource_class = ::Client

          def core_token_class = ::ClientToken

          def core_resource_type = "client"
        end
      end
    end
  end
end
