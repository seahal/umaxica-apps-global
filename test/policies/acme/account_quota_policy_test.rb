# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::AccountQuotaPolicyTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
  end

  test "allows when there are no accounts" do
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client, scope: Persona.none)

    assert_predicate policy, :allowed?
    assert_not_predicate policy, :exceeded?
    assert_equal 10, policy.limit
    assert_equal 0, policy.current_count
    assert_equal 10, policy.remaining
  end

  test "allows when count is limit minus one" do
    create_personas(9)
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client)

    assert_predicate policy, :allowed?
    assert_equal 9, policy.current_count
    assert_equal 1, policy.remaining
  end

  test "rejects when count reaches limit" do
    create_personas(10)
    policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: client)

    assert_not_predicate policy, :allowed?
    assert_predicate policy, :exceeded?
    assert_equal 0, policy.remaining
  end

  test "behaves the same across surfaces" do
    assert_surface_policy(:app, Persona, -> { create_personas(1) }, client)
    assert_surface_policy(:org, Agent, -> { create_agents(1) }, operator)
    assert_surface_policy(:com, Individual, -> { create_individuals(1) }, visitor)
  end

  private

  def assert_surface_policy(surface, model_class, setup_proc, principal)
    setup_proc.call
    policy = Acme::AccountQuotaPolicy.new(surface: surface, principal: principal)

    assert_predicate policy, :allowed?
    assert_equal 1, policy.current_count
    assert_equal 9, policy.remaining
    assert_equal model_class, policy.send(:account_class)
  end

  def client
    @client ||= Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def operator
    @operator ||= Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
  end

  def visitor
    @visitor ||= Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  def create_personas(count)
    count.times do |index|
      Persona.create!(client_identity: client_identity("client-#{index}"), title: "P#{index}")
    end
  end

  def create_agents(count)
    count.times { Agent.create!(operator_identity: operator_identity, title: "A#{SecureRandom.hex(2)}") }
  end

  def create_individuals(count)
    count.times { Individual.create!(visitor_identity: visitor_identity, title: "I#{SecureRandom.hex(2)}") }
  end

  def client_identity(label = "client")
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-quota-#{label}",
      audience: "acme_app",
      source_record_id: Zlib.crc32("client-quota-#{label}"),
      status_id: ClientIdentityState::ACTIVE,
    )
  end

  def operator_identity
    @operator_identity ||= OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "operator-quota",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000_000),
      status_id: OperatorIdentityState::ACTIVE,
    )
  end

  def visitor_identity
    @visitor_identity ||= VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "visitor-quota",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000_000),
      status_id: VisitorIdentityState::ACTIVE,
    )
  end
end
