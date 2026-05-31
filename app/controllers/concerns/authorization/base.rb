# typed: false
# frozen_string_literal: true

module Authorization
  # Authorization for this app is handled entirely by Action Policy (see
  # ApplicationPolicy and app/policies). This concern is retained only as the
  # shared base that Authorization::{Client,Operator,Visitor} include; it holds
  # no request hook so it can never act as an implicit allow.
  module Base
    extend ActiveSupport::Concern
  end
end
