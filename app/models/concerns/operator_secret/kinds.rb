# typed: false
# frozen_string_literal: true

module OperatorSecret::Kinds
  extend ActiveSupport::Concern

  # Kind constants (integer IDs)
  LOGIN = OperatorSecretKind::LOGIN
  PERMANENT = OperatorSecretKind::PERMANENT
  ONE_TIME = OperatorSecretKind::ONE_TIME

  ALL = [LOGIN].freeze

  # Predicates using string equality on staff_secret_kind_id column (no JOINs)
  def login_secret?
    staff_secret_kind_id == LOGIN
  end

  def permanent_secret?
    staff_secret_kind_id == PERMANENT
  end

  def one_time_secret?
    staff_secret_kind_id == ONE_TIME
  end
end
