# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module News
        module Com
          class EntriesController < Base::Org::BareController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :bare
            PUBLISHING_SURFACE = "news"
            PUBLISHING_AUDIENCE = "com"
            ENTRY_CLASS = ::Publishing::News::Com::Entry

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
