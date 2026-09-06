# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module Docs
        module App
          class EntriesController < Base::Org::BareController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :bare
            PUBLISHING_SURFACE = "docs"
            PUBLISHING_AUDIENCE = "app"
            ENTRY_CLASS = ::Publishing::Docs::App::Entry

            def index
              super
            end

            def show
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
