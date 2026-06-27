# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_individual_bindings
# Database name: avatar
#
#  avatar_id     :bigint           not null
#  created_at    :datetime         not null
#  id            :bigint           not null, primary key
#  individual_id :bigint           not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_avatar_individual_bindings_on_avatar_id        (avatar_id) UNIQUE
#  index_avatar_individual_bindings_on_individual_id     (individual_id) UNIQUE
#
class AvatarIndividualBinding < AvatarRecord
  belongs_to :avatar, inverse_of: :avatar_individual_binding
  belongs_to :individual, inverse_of: :avatar_individual_binding

  validates :avatar_id, uniqueness: true
  validates :individual_id, uniqueness: true
end
