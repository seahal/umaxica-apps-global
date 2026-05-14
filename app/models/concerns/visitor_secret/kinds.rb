# typed: false
# frozen_string_literal: true

module VisitorSecret::Kinds
  extend ActiveSupport::Concern

  LOGIN = VisitorSecretKind::LOGIN
  RECOVERY = VisitorSecretKind::RECOVERY
  API = VisitorSecretKind::API
  PERMANENT = VisitorSecretKind::PERMANENT
  ONE_TIME = VisitorSecretKind::ONE_TIME

  ALL = [LOGIN, RECOVERY, API].freeze

  def login_secret?
    visitor_secret_kind_id == LOGIN
  end

  def recovery_secret?
    visitor_secret_kind_id == RECOVERY
  end

  def api_secret?
    visitor_secret_kind_id == API
  end

  def permanent_secret?
    visitor_secret_kind_id == PERMANENT
  end

  def one_time_secret?
    visitor_secret_kind_id == ONE_TIME
  end
end
