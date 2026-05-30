# typed: false
# frozen_string_literal: true

# Authorization for ClientChronicle activity-log listings (app client + com visitor surfaces).
#
# ClientChronicle rows record both Client and Visitor activity (distinguished by `subject_type`).
# The activity-log controllers (`Sign::App::Configuration::ActivitiesController`,
# `Sign::Com::Configuration::ActivitiesController`) already constrain the query to the current
# actor's own rows (`subject_id == current_actor.id`); this policy gates the actor *type* allowed
# to reach a listing at all. `show` delegates to `index` in those controllers, so both rules apply.
class ClientChroniclePolicy < ApplicationPolicy
  def index?
    user.is_a?(Client) || user.is_a?(Visitor)
  end

  alias_method :show?, :index?
end
