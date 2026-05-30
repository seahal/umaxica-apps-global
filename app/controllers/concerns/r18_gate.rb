# typed: false
# frozen_string_literal: true

module R18Gate
  extend ActiveSupport::Concern
  include Common::Redirect

  COOKIE_KEY = :r18_acknowledged
  COOKIE_TTL = 30.days

  included do
    # `class_attribute` mutation is class-definition-time only — `r18_required`
    # is invoked from the controller class body during boot, before any
    # request threads exist. Per-class isolation comes from class_attribute's
    # inheritance-aware setter.
    class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    before_action :require_r18_viewing!
  end

  class_methods do
    def r18_required(*actions)
      self.r18_required_actions = r18_required_actions | actions.map(&:to_s).to_set
    end
  end

  private

  def require_r18_viewing!
    return unless r18_content_required?

    set_r18_no_store!
    return head :forbidden unless request.get? || request.head?
    return if logged_in? ? logged_in_r18_allowed? : anonymous_r18_allowed?

    redirect_to(r18_gate_path_for(request.fullpath), allow_other_host: false) unless performed?
  end

  def logged_in_r18_allowed?
    actor = current_resource if respond_to?(:current_resource, true)
    return render_r18_blocked unless actor&.respond_to?(:birthdate)
    return render_r18_blocked unless AgeEligibility.minimum_age_reached?(
      actor.birthdate,
      minimum_age: 18,
      today: Time.zone.today,
    )

    case r18_display_preference_state(actor)
    when :stopped
      return render_r18_stopped
    when :ask
      return true if session["r18_view_once"] == true

      redirect_to(r18_gate_path_for(request.fullpath), allow_other_host: false)
      return false
    end

    true
  end

  def anonymous_r18_allowed?
    cookies.signed[COOKIE_KEY] == "1"
  end

  def acknowledge_r18!
    cookies.signed[COOKIE_KEY] = r18_cookie_options.merge(value: "1", expires: COOKIE_TTL.from_now)
  end

  def acknowledge_r18_view_once!
    session["r18_view_once"] = true
  end

  def r18_cookie_options
    {
      httponly: true,
      secure: Rails.env.production? || ENV["FORCE_SECURE_COOKIES"].present? || request.ssl?,
      same_site: :lax,
      path: "/",
    }
  end

  def r18_safe_pt(value)
    safe_internal_path(value).presence || r18_fallback_path
  end

  def adult_content_gate_enabled?(actor)
    r18_display_preference_state(actor) == :stopped
  end

  def r18_display_preference_state(actor)
    preference = r18_actor_preference(actor)
    stopper = r18_preference_stopper(preference)
    return :ask unless stopper

    if stopper.respond_to?(:approved?) || stopper.respond_to?(:denied?)
      return :allow if stopper.respond_to?(:approved?) && stopper.approved?
      return :stopped if stopper.respond_to?(:denied?) && stopper.denied?

      return :ask
    end

    if stopper.respond_to?(:enabled?)
      return :stopped if stopper.enabled?

      return :allow
    end

    case stopper.to_s
    when "approved", "disabled" then :allow
    when "deny", "enabled" then :stopped
    else :ask
    end
  end

  def r18_preference_stopper(preference)
    return unless preference

    association = "#{preference.class.name.underscore}_adult_content_gate"
    return preference.public_send(association) if preference.respond_to?(association)

    preference.public_send(:adult_content_gate) if preference.respond_to?(:adult_content_gate)
  end

  def r18_actor_preference(actor)
    if actor.respond_to?(:user_preference)
      actor.user_preference
    elsif actor.respond_to?(:visitor_preference)
      actor.visitor_preference
    elsif actor.respond_to?(:staff_preference)
      actor.staff_preference
    end
  end

  def render_r18_blocked
    redirect_to(r18_blocked_path, allow_other_host: false)
    false
  end

  def render_r18_stopped
    redirect_to(r18_stopped_path, allow_other_host: false)
    false
  end

  def set_r18_no_store!
    response.headers["Cache-Control"] = "no-store, private"
  end

  def r18_content_required?
    r18_required_actions.include?(action_name)
  end

  def r18_gate_path_for(pt)
    r18_gate_path(pt: pt)
  end

  def r18_gate_path(pt:)
    raise NotImplementedError, "#{self.class} must define #r18_gate_path"
  end

  def r18_blocked_path
    raise NotImplementedError, "#{self.class} must define #r18_blocked_path"
  end

  def r18_stopped_path
    raise NotImplementedError, "#{self.class} must define #r18_stopped_path"
  end

  def r18_fallback_path
    "/"
  end
end
