# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: enterprises
# Database name: app_zenith
#
#  id           :bigint           not null, primary key
#  lock_version :integer          default(0), not null
#  name         :string           default(""), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string           default(""), not null
#
# Indexes
#
#  index_enterprises_on_public_id  (public_id) UNIQUE
#
class Enterprise < AppRpRecord
  include ::Collective

  has_many :enterprise_units, dependent: :destroy, inverse_of: :enterprise
  has_many :persona_memberships, dependent: :restrict_with_error, inverse_of: :enterprise

  def root_units
    enterprise_units.where(parent_id: nil)
  end
end
