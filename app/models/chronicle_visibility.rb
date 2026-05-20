# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_visibilities
# Database name: chronicle
#
#  id                              :bigint           not null, primary key
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  chronicle_id                    :bigint           not null
#  chronicle_visibility_context_id :bigint           not null
#
# Indexes
#
#  idx_chronicle_visibilities_unique_context          (chronicle_id,chronicle_visibility_context_id) UNIQUE
#  idx_on_chronicle_visibility_context_id_2c36ec5eab  (chronicle_visibility_context_id)
#  index_chronicle_visibilities_on_chronicle_id       (chronicle_id)
#
# Foreign Keys
#
#  fk_rails_...  (chronicle_id => chronicles.id)
#  fk_rails_...  (chronicle_visibility_context_id => chronicle_visibility_contexts.id)
#
class ChronicleVisibility < ChronicleRecord
  belongs_to :chronicle
  belongs_to :chronicle_visibility_context

  validates :chronicle_visibility_context_id, uniqueness: { scope: :chronicle_id }
end
