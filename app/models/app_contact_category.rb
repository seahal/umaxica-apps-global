# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_categories
# Database name: guest
#
#  id :bigint           not null, primary key
#
class AppContactCategory < GuestRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LEGACY_NOTHING = 1
  APPLICATION_INQUIRY = 2
  DEFAULTS = [NOTHING, LEGACY_NOTHING, APPLICATION_INQUIRY].freeze

  has_many :app_contacts,
           foreign_key: :category_id,
           inverse_of: :app_contact_category,
           dependent: :restrict_with_exception

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
