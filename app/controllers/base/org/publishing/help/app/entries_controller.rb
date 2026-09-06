# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module Help
        module App
          class EntriesController < Base::Org::ApplicationController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :private
            declare_authentication_mode! :private
            PUBLISHING_SURFACE = "help"
            PUBLISHING_AUDIENCE = "app"
            ENTRY_CLASS = ::Publishing::Help::App::Entry

            def index
              super
            end

            def show
              super
            end

            def new
              super
            end

            def create
              super
            end

            def edit
              super
            end

            def update
              super
            end
          end
        end
      end
    end
  end
end
