# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_memberships
# Database name: app_principal
#
#  id           :bigint           not null, primary key
#  joined_at    :datetime         not null
#  left_at      :datetime         default(-Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#  workspace_id :bigint           not null
#
# Indexes
#
#  index_user_memberships_on_user_id_and_workspace_id  (user_id,workspace_id) UNIQUE
#  index_user_memberships_on_workspace_id              (workspace_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

class ClientMembership < AppPrincipalRecord
  self.table_name = "user_memberships"
  belongs_to :user, class_name: "Client", inverse_of: :client_memberships

  validates :user_id, uniqueness: { scope: :workspace_id }
end
