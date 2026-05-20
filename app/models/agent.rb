# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agents
# Database name: org_zenith
#
#  id                   :bigint           not null, primary key
#  lock_version         :integer          default(0), not null
#  moniker              :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  operator_identity_id :bigint           not null
#  public_id            :string           default(""), not null
#
# Indexes
#
#  idx_agents_one_per_operator_identity  (operator_identity_id) UNIQUE
#  index_agents_on_operator_identity_id  (operator_identity_id)
#  index_agents_on_public_id             (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (operator_identity_id => operator_identities.id)
#
class Agent < OrgRpRecord
  include ::Account

  belongs_to :operator_identity, inverse_of: :agent
  has_many :agent_memberships, dependent: :destroy, inverse_of: :agent

  validates :operator_identity_id, uniqueness: true
end
