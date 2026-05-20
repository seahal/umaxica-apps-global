# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_retention_policies
# Database name: chronicle
#
#  id            :bigint           not null, primary key
#  code          :string           not null
#  duration_days :integer          not null
#  name          :string           not null
#  permanent     :boolean          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_chronicle_retention_policies_on_code  (code) UNIQUE
#
class ChronicleRetentionPolicy < ChronicleRecord
  has_many :chronicles, dependent: :restrict_with_error, inverse_of: :chronicle_retention_policy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, length: { maximum: 128 }
  validates :code, length: { maximum: 64 }
  validates :duration_days, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :permanent, inclusion: { in: [true, false] }
  validate :permanent_duration_must_be_zero

  private

  def permanent_duration_must_be_zero
    return unless permanent?
    return if duration_days == 0

    errors.add(:duration_days, "must be 0 for permanent retention")
  end
end
