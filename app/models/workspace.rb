# typed: false
# == Schema Information
#
# Table name: workspaces
# Database name: operator
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# frozen_string_literal: true

# Workspace uses the conventional workspaces table.
class Workspace < OperatorRecord
  has_many :user_memberships, dependent: :destroy, inverse_of: :workspace

  validates :name, presence: true
end
