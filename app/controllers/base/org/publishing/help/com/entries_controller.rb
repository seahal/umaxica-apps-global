# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module Help
        module Com
          class EntriesController < Base::Org::BareController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :bare
            PUBLISHING_SURFACE = "help"
            PUBLISHING_AUDIENCE = "com"
            ENTRY_CLASS = ::Publishing::Help::Com::Entry

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
