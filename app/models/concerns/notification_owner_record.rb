# typed: false
# frozen_string_literal: true

module NotificationOwnerRecord
  extend ActiveSupport::Concern

  included do
    include ::PublicId
  end
end
