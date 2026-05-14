# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class VisitorAccountStatus < PrincipalRecord
  self.table_name = "client_statuses"

  has_many :clients,
           class_name: "VisitorAccount",
           inverse_of: :client_status,
           dependent: :restrict_with_exception
  has_many :status_clients,
           class_name: "VisitorAccount",
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_exception
end
