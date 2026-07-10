# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_visibilities
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientVisibility < AppPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  USER = 1
  STAFF = 2
  BOTH = 3
  DEFAULTS = [NOTHING, USER, STAFF, BOTH].freeze

  has_many :users, class_name: "Client",
                   foreign_key: :visibility_id,
                   dependent: :restrict_with_error,
                   inverse_of: :visibility
  has_many :clients, class_name: "Client",
                     foreign_key: :visibility_id,
                     dependent: :restrict_with_error,
                     inverse_of: :visibility
end
