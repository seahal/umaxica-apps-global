# typed: false
# frozen_string_literal: true

# Raised when a record that must be addressable by clients carries a blank `public_id`.
#
# `public_id` columns are `null: false, default: ""`, so a row written around the model layer -- an
# `insert_all`, a raw statement, a fixture -- can persist a blank one even though the `PublicId`
# concern generates and validates it on create. Callers must not paper over that by substituting the
# database primary key: an internal identifier on the public wire is worse than an error.
class BlankPublicIdentifierError < ApplicationError
  attr_reader :record_class

  def initialize(record_class:)
    @record_class = record_class.to_s
    super(nil, :internal_server_error, record_class: @record_class)
  end

  def message
    "#{record_class} has a blank public_id and cannot be exposed to a client"
  end
end
