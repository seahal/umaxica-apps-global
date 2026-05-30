# typed: false
# frozen_string_literal: true

module OperatorSecretCredential::Kinds
  extend ActiveSupport::Concern

  # Kind constants (integer IDs)
  LOGIN = OperatorSecretCredentialKind::LOGIN
  PERMANENT = OperatorSecretCredentialKind::PERMANENT
  ONE_TIME = OperatorSecretCredentialKind::ONE_TIME

  ALL = [LOGIN].freeze

  # Predicates using string equality on staff_secret_kind_id column (no JOINs)
  def login_secret_credential?
    staff_secret_kind_id == LOGIN
  end

  def permanent_secret_credential?
    staff_secret_kind_id == PERMANENT
  end

  def one_time_secret_credential?
    staff_secret_kind_id == ONE_TIME
  end
end
