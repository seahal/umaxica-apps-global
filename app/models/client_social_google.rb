# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_social_googles
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
#  index_client_social_googles_on_discarded_at           (discarded_at)
#  index_client_social_googles_on_purged_at              (purged_at)
#  index_client_social_googles_on_status_id              (status_id)
#  index_client_social_googles_on_token_expires_at       (token_expires_at)
#  index_client_social_googles_on_uid_and_provider       (uid,provider) UNIQUE
#  index_user_identity_social_googles_on_user_id_unique  (user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_social_google_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

class ClientSocialGoogle < AppPrincipalRecord
  include Retainable
  include SocialIdentifiable

  alias_attribute :expires_at, :token_expires_at
  attribute :status_id, default: ClientSocialGoogleStatus::ACTIVE

  belongs_to :user, class_name: "Client", inverse_of: :user_social_google
  belongs_to :user_social_google_status, class_name: "ClientSocialGoogleStatus",
                                         inverse_of: :client_social_googles,
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
    ClientSocialGoogleStatus
  end
end
