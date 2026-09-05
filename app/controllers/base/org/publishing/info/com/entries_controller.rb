# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module Info
        module Com
          class EntriesController < Base::Org::BareController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :bare
            PUBLISHING_SURFACE = "info"
            PUBLISHING_AUDIENCE = "com"
            ENTRY_CLASS = ::Publishing::Info::Com::Entry

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
