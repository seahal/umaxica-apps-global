# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_agent_bindings
# Database name: avatar
#
#  agent_id   :bigint           not null
#  avatar_id  :bigint           not null
#  created_at :datetime         not null
#  id         :bigint           not null, primary key
#  updated_at :datetime         not null
#
# Indexes
#
#  index_avatar_agent_bindings_on_agent_id   (agent_id) UNIQUE
#  index_avatar_agent_bindings_on_avatar_id  (avatar_id) UNIQUE
#
class AvatarAgentBinding < AvatarRecord
  belongs_to :avatar, inverse_of: :avatar_agent_binding
  belongs_to :agent, inverse_of: :avatar_agent_binding

  validates :avatar_id, uniqueness: true
  validates :agent_id, uniqueness: true
end
