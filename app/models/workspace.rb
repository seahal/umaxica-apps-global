# typed: false
# == Schema Information
#
# Table name: workspaces
# Database name: org_principal
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# frozen_string_literal: true

# Workspace uses the conventional workspaces table.
class Workspace < OrgPrincipalRecord
  validates :name, presence: true
end
