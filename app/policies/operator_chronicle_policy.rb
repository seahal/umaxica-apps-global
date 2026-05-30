# typed: false
# frozen_string_literal: true

# Authorization for OperatorChronicle activity-log listings (org operator surface).
#
# `Sign::Org::Configuration::ActivitiesController` already constrains the query to the current
# operator's own rows (`subject_id == current_operator.id`); this policy gates the actor *type*
# allowed to reach a listing at all. `show` delegates to `index` in that controller, so both apply.
class OperatorChroniclePolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator)
  end

  alias_method :show?, :index?
end
