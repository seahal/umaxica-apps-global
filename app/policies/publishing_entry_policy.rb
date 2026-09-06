# typed: false
# frozen_string_literal: true

# Authorization for the staff Publishing CMS.
#
# The CMS reads and writes content for all twelve cells, so the record it is
# asked about is an entry from one of twelve classes, or the operator itself
# for the collection actions. None of those distinctions change the answer:
# what the CMS requires is a staff operator whose account is currently in
# force. Cell separation is a routing and query concern -- each controller
# names one `ENTRY_CLASS` and the query never crosses it -- not something a
# policy can restate without duplicating it.
#
# `active?` is the same predicate `AuthenticationOperator#active_operator?`
# uses: an operator who has withdrawn, is closing, is suspended, or has been
# terminated keeps a valid session until it expires, and must not be able to
# publish with it.
class PublishingEntryPolicy < ApplicationPolicy
  def index? = staff_operator_in_force?

  def show? = staff_operator_in_force?

  def create? = staff_operator_in_force?

  def update? = staff_operator_in_force?

  def destroy? = staff_operator_in_force?

  private

  def staff_operator_in_force?
    user.is_a?(Operator) && user.active?
  end
end
