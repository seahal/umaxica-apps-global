# typed: false
# frozen_string_literal: true

class RedirectsPriorityResolver
  def self.call(priority:, routes:, params: {}, default:)
    new(priority: priority, routes: routes, params: params, default: default).call
  end

  def initialize(priority:, routes:, params:, default:)
    @priority = priority
    @routes = routes
    @params = params
    @default = default
  end

  def call
    Array(priority).each do |entry|
      result = resolve_entry(entry)
      return result if result.ok?
      return result if fail_closed?(result)
    end

    RedirectsPathTargetResolver.call(default, source: :default_path)
  end

  private

  attr_reader :priority, :routes, :params, :default

  def resolve_entry(entry)
    case entry.fetch(:kind).to_sym
    when :nt
      RedirectsNavigationTargetResolver.call(
        entry[:value], routes: routes, params: params, scope: entry[:scope],
                       source: entry.fetch(:source, :priority_nt),
      )
    when :signed_nt
      RedirectsNavigationTargetResolver.call(
        entry[:value], routes: routes, params: params, scope: entry[:scope],
                       source: entry.fetch(:source, :signed_nt),
      )
    when :signed_pt
      RedirectsPathTargetResolver.call(entry[:value], source: entry.fetch(:source, :signed_pt))
    when :pt
      RedirectsPathTargetResolver.call(entry[:value], source: entry.fetch(:source, :raw_pt))
    else
      RedirectsTargetResult.failure(
        kind: entry[:kind], source: :priority, reason: :unknown_kind,
        unsafe_value: entry[:value],
      )
    end
  end

  def fail_closed?(result)
    %w(control_char encoded_control_char encoded_host_escape backslash protocol_relative scheme host userinfo
       raw_url).include?(
         result.failure_reason.to_s,
       )
  end
end
