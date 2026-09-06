# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module News
        module Org
          class EntriesController < Base::Org::ApplicationController
            include ::PublishingManagementEntriesActions

            AUTHENTICATION_MODE = :private
            declare_authentication_mode! :private
            PUBLISHING_SURFACE = "news"
            PUBLISHING_AUDIENCE = "org"
            ENTRY_CLASS = ::Publishing::News::Org::Entry

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
