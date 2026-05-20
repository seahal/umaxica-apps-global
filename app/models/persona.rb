# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: personas
# Database name: app_zenith
#
#  id                 :bigint           not null, primary key
#  lock_version       :integer          default(0), not null
#  moniker            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_identity_id :bigint           not null
#  public_id          :string           default(""), not null
#
# Indexes
#
#  idx_personas_one_per_client_identity  (client_identity_id) UNIQUE
#  index_personas_on_client_identity_id  (client_identity_id)
#  index_personas_on_public_id           (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (client_identity_id => client_identities.id)
#
class Persona < AppRpRecord
  include ::Account

  belongs_to :client_identity, inverse_of: :persona
  has_many :persona_memberships, dependent: :destroy, inverse_of: :persona

  validates :client_identity_id, uniqueness: true
end
