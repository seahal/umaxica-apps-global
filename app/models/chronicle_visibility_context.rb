# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_visibility_contexts
# Database name: chronicle
#
#  id         :bigint           not null, primary key
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chronicle_visibility_contexts_on_code  (code) UNIQUE
#
class ChronicleVisibilityContext < ChronicleRecord
  has_many :chronicle_visibilities, dependent: :restrict_with_error, inverse_of: :chronicle_visibility_context
  has_many :chronicles, through: :chronicle_visibilities

  validates :code, presence: true, uniqueness: true
  validates :code, length: { maximum: 64 }
  validates :name, presence: true, length: { maximum: 128 }
end
