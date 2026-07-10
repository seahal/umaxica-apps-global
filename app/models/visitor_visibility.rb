# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_visibilities
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

class VisitorVisibility < ComPrincipalRecord
  include ReferenceRecord

  NOBODY = 0
  VISITOR = 1
  STAFF = 2
  BOTH = 3
  DEFAULTS = [NOBODY, VISITOR, STAFF, BOTH].freeze

  has_many :visitors,
           foreign_key: :visibility_id,
           dependent: :restrict_with_error,
           inverse_of: :visibility
end
