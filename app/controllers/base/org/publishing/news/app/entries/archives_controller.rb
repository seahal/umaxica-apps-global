# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module News
        module App
          module Entries
            class ArchivesController < Base::Org::ApplicationController
              include ::PublishingManagementArchivesActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "news"
              PUBLISHING_AUDIENCE = "app"
              ENTRY_CLASS = ::Publishing::News::App::Entry

              def create
                super
              end

              def destroy
                super
              end
            end
          end
        end
      end
    end
  end
end
