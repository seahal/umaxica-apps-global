# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handles
# Database name: avatar
#
#  id               :bigint           not null, primary key
#  cooldown_until   :datetime         not null
#  handle           :string           not null
#  is_system        :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  handle_status_id :bigint
#  public_id        :string           not null
#
# Indexes
#
#  index_handles_on_cooldown_until    (cooldown_until)
#  index_handles_on_handle_status_id  (handle_status_id)
#  index_handles_on_is_system         (is_system)
#  index_handles_on_public_id         (public_id) UNIQUE
#  uniq_handles_handle_non_system     (handle) UNIQUE WHERE (is_system = false)
#
# Foreign Keys
#
#  fk_rails_...  (handle_status_id => handle_statuses.id)
#

class Handle < AvatarRecord
  include PublicId

  attribute :handle_status_id, default: HandleStatus::NOTHING

  belongs_to :handle_status

  has_many :handle_assignments, dependent: :restrict_with_error
  has_many :avatars, through: :handle_assignments
  has_many :active_avatars,
           class_name: "Avatar",
           foreign_key: "active_handle_id",
           inverse_of: :active_handle,
           dependent: :restrict_with_error

  validates :public_id, presence: true, uniqueness: true
  validates :handle, presence: true
  validates :handle, uniqueness: { conditions: -> { where(is_system: false) } },
                     unless: :is_system?
  validates :cooldown_until, presence: true
end
