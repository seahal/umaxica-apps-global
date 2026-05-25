# typed: false
# frozen_string_literal: true

mission_control = Rails.application.credentials.mission_control
MissionControl::Jobs.base_controller_class = "Apex::Dev::ApplicationController"
MissionControl::Jobs.http_basic_auth_user     = mission_control&.http_basic_auth_user
MissionControl::Jobs.http_basic_auth_password = mission_control&.http_basic_auth_password
