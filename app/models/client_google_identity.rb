# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_google_identities
# Database name: app_principal
#
#  id                    :bigint           not null, primary key
#  discarded_at          :datetime         default(Infinity), not null
#  last_authenticated_at :datetime
#  provider              :string           default("google_app"), not null
#  purged_at             :datetime         default(Infinity), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  status_id             :bigint           default(1), not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_client_google_identities_on_discarded_at        (discarded_at)
#  index_client_google_identities_on_purged_at           (purged_at)
#  index_client_google_identities_on_status_id           (status_id)
#  index_client_google_identities_on_token_expires_at    (token_expires_at)
#  index_client_google_identities_on_uid_and_provider    (uid,provider) UNIQUE
#  index_user_identity_social_googles_on_user_id_unique  (user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_google_identity_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

class ClientGoogleIdentity < AppPrincipalRecord
  include Retainable
  include SocialIdentifiable

  self.filter_attributes += %w(token refresh_token uid)

  alias_attribute :expires_at, :token_expires_at
  attribute :status_id, default: ClientGoogleIdentityStatus::ACTIVE

  belongs_to :user, class_name: "Client", inverse_of: :user_google_identity
  belongs_to :user_google_identity_status, class_name: "ClientGoogleIdentityStatus",
                                           inverse_of: :client_google_identities,
                                           foreign_key: :status_id

  validates :token, presence: true
  validates :user_id, uniqueness: { conditions: -> { where.not(user_id: nil) } }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :token_expires_at, presence: true
  validates :status_id, numericality: { only_integer: true }

  def self.status_column
    :status_id
  end

  def self.status_class
    ClientGoogleIdentityStatus
  end
end
