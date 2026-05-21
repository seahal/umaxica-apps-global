# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individuals
# Database name: com_zenith
#
#  id                  :bigint           not null, primary key
#  lock_version        :integer          default(0), not null
#  moniker             :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  public_id           :string           default(""), not null
#  visitor_identity_id :bigint           not null
#
# Indexes
#
#  idx_individuals_one_per_visitor_identity  (visitor_identity_id) UNIQUE
#  index_individuals_on_public_id            (public_id) UNIQUE
#  index_individuals_on_visitor_identity_id  (visitor_identity_id)
#
class Individual < ComRpRecord
  include ::Account

  belongs_to :visitor_identity, inverse_of: :individual
  has_many :individual_memberships, dependent: :destroy, inverse_of: :individual

  validates :visitor_identity_id, uniqueness: true
end
