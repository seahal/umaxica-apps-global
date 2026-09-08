# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Publishing
      module News
        module Com
          module Entries
            class PublicationsController < Base::Org::ApplicationController
              include ::PublishingManagementPublicationsActions

              AUTHENTICATION_MODE = :private
              declare_authentication_mode! :private
              PUBLISHING_SURFACE = "news"
              PUBLISHING_AUDIENCE = "com"
              ENTRY_CLASS = ::Publishing::News::Com::Entry

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
