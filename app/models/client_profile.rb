# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_profiles
# Database name: app_zenith
#
#  id               :bigint           not null, primary key
#  lock_version     :integer          default(0), not null
#  moniker          :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_status_id :bigint           default(0), not null
#  division_id      :bigint
#  public_id        :string           not null
#  status_id        :bigint           default(0), not null
#  user_id          :bigint
#
# Indexes
#
#  index_client_profiles_on_client_status_id  (client_status_id)
#  index_client_profiles_on_division_id       (division_id)
#  index_client_profiles_on_public_id         (public_id) UNIQUE
#  index_client_profiles_on_status_id         (status_id)
#  index_client_profiles_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_status_id => visitor_account_statuses.id)
#  fk_rails_...  (status_id => visitor_account_statuses.id)
#
class ClientProfile < AppRpRecord
  belongs_to :client_status,
             class_name: "VisitorAccountStatus",
             inverse_of: :clients
  belongs_to :status,
             class_name: "VisitorAccountStatus",
             inverse_of: :status_clients
  belongs_to :user,
             class_name: "Client",
             inverse_of: false
end
