# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_profile_statuses
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
class ClientProfileStatus < AppRpRecord
  has_many :clients,
           class_name: "ClientProfile",
           inverse_of: :client_status,
           dependent: :restrict_with_exception
  has_many :status_clients,
           class_name: "ClientProfile",
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_exception
end
