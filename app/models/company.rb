# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
# Database name: com_zenith
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
#  index_companies_on_public_id  (public_id) UNIQUE
#
class Company < ComRpRecord
  include ::Collective

  has_many :company_units, dependent: :destroy, inverse_of: :company
  has_many :individual_memberships, dependent: :restrict_with_error, inverse_of: :company

  def root_units
    company_units.where(parent_id: nil)
  end
end
