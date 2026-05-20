# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: bureaus
# Database name: org_zenith
#
#  id           :bigint           not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string           default(""), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string           default(""), not null
#
# Indexes
#
#  index_bureaus_on_public_id  (public_id) UNIQUE
#
class Bureau < OrgRpRecord
  include ::Collective

  has_many :bureau_units, dependent: :destroy, inverse_of: :bureau
  has_many :agent_memberships, dependent: :restrict_with_error, inverse_of: :bureau

  def root_units
    bureau_units.where(parent_id: nil)
  end
end
