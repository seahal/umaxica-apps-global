# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_visitor_statuses
# Database name: visitor
#
#  id :bigint           not null, primary key
#
class VisitorClientStatus < VisitorRecord
  self.table_name = "client_visitor_statuses"

  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :client_visitors,
           class_name: "VisitorClient",
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :client_visitor_status
end
