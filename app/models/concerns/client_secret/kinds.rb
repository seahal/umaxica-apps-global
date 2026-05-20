# typed: false
# frozen_string_literal: true

module ClientSecret::Kinds
  extend ActiveSupport::Concern

  # Kind constants
  LOGIN = ClientSecretKind::LOGIN
  TOTP = ClientSecretKind::TOTP
  RECOVERY = ClientSecretKind::RECOVERY
  API = ClientSecretKind::API
  PERMANENT = ClientSecretKind::PERMANENT
  ONE_TIME = ClientSecretKind::ONE_TIME

  ALL = [LOGIN, TOTP, RECOVERY, API].freeze

  # Predicates using string equality on user_secret_kind_id column (no JOINs)
  def login_secret?
    user_secret_kind_id == LOGIN
  end

  def totp_secret?
    user_secret_kind_id == TOTP
  end

  def recovery_secret?
    user_secret_kind_id == RECOVERY
  end

  def api_secret?
    user_secret_kind_id == API
  end

  def permanent_secret?
    user_secret_kind_id == PERMANENT
  end

  def one_time_secret?
    user_secret_kind_id == ONE_TIME
  end
end
