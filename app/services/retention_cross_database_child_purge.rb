# typed: false
# frozen_string_literal: true

# Explicitly deletes a principal's *non-audit* children that live in a
# different database than the principal itself.
#
# These associations have no DB-level foreign key to the principal (the
# boundary is a separate Postgres database) and previously leaned on an
# implicit `dependent: :destroy/:nullify` AR cascade. That cascade is a
# non-atomic, pseudo cross-DB referential-integrity mechanism — and for the
# purge path it never even ran (Client/Visitor are anonymized, Operator is
# removed via set-based `delete_all`, both of which skip `dependent:`),
# leaving cross-DB orphans.
#
# This service makes that cleanup explicit and ordered, invoked from the
# account purge path. It uses set-based `delete_all` on each child model's
# own connection (no callbacks, no row loading).
#
# Chronicle (audit) children are intentionally NOT purged here: chronicle is
# append-only audit history that must outlive actor purge. See
# adr/chronicle-audit-db-consolidation.md.
class RetentionCrossDatabaseChildPurge
  def self.call(actor:)
    new(actor:).call
  end

  def initialize(actor:)
    @actor = actor
  end

  def call
    case actor
    when Client   then purge_client
    when Visitor  then purge_visitor
    when Operator then purge_operator
    end
    actor
  end

  private

  attr_reader :actor

  # NOTE: model-scoped `delete_all` issues a real SQL DELETE on the child's
  # own connection. An association-proxy `delete_all` would instead NULLify
  # the (NOT NULL) foreign key, so it must not be used here.
  def purge_client
    ClientNotificationRecord.where(user_id: actor.id).delete_all # app_signal DB
    AvatarAssignment.where(user_id: actor.id).delete_all         # avatar DB (join rows only)
  end

  def purge_visitor
    VisitorNotificationRecord.where(visitor_id: actor.id).delete_all # com_signal DB
    VisitorAccount.where(visitor_id: actor.id).delete_all # com_zenith DB
  end

  def purge_operator
    OperatorNotificationRecord.where(staff_id: actor.id).delete_all # org_signal DB
  end
end
