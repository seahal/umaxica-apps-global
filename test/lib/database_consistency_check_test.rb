# typed: false
# frozen_string_literal: true

require "test_helper"

class DatabaseConsistencyCheckTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless defined?(DbConsistencyCheckers::NullConstraintChecker)
  end

  test "null constraint checker handles presence validators without crashing" do
    checker = DbConsistencyCheckers::NullConstraintChecker.new

    assert_kind_of Array, checker.check([ClientEmail])
  end

  test "null constraint checker ignores not null columns with database defaults" do
    checker = DbConsistencyCheckers::NullConstraintChecker.new

    assert_empty checker.check([ClientPreference])
  end

  test "null constraint checker accepts the remaining high-confidence model fixes" do
    checker = DbConsistencyCheckers::NullConstraintChecker.new

    assert_empty checker.check(
      [
        BureauUnitClosure,
        ClientMembership,
        ClientProfile,
        CompanyUnitClosure,
        EnterpriseUnitClosure,
        HandleAssignment,
        OperatorLifecycleRequest,
      ],
    )
  end

  test "column presence checker handles presence validators without crashing" do
    checker = DbConsistencyCheckers::ColumnPresenceChecker.new

    assert_kind_of Array, checker.check([OrganizationInvitation])
  end

  test "column presence checker ignores conditional presence validators and accepts required entry methods" do
    checker = DbConsistencyCheckers::ColumnPresenceChecker.new

    assert_empty checker.check([ClientSignUpFlow, VisitorSignUpFlow, OperatorLifecycleRequest])
  end

  test "missing index checker accepts supported foreign key indexes" do
    checker = DbConsistencyCheckers::MissingIndexChecker.new

    assert_empty checker.check(
      [ComPreferenceChronicle, HandleAssignment, OrgPreferenceChronicle,
       OperatorLifecycleRequest,],
    )
  end

  test "foreign key checker accepts the repaired same-database foreign keys" do
    checker = DbConsistencyCheckers::ForeignKeyChecker.new

    warnings = checker.check([Agent, ClientPreference, Individual, OperatorLifecycleRequest, Persona])

    columns = warnings.pluck(:column)

    assert_not_includes columns, "operator_identity_id"
    assert_not_includes columns, "user_id"
    assert_not_includes columns, "visitor_identity_id"
    assert_not_includes columns, "requested_by_operator_id"
    assert_not_includes columns, "client_identity_id"
  end

  test "foreign key cascade checker accepts explicit delete rules and inverse dependent associations" do
    checker = DbConsistencyCheckers::ForeignKeyCascadeChecker.new

    warnings = checker.check(
      [
        Agent,
        AgentMembership,
        AvatarBlock,
        AvatarMute,
        BureauUnit,
        ChronicleOutboxEntry,
        ClientPreference,
        ClientSignUpFlow,
        ClientToken,
        ClientWithdrawalFlowEvent,
        CompanyUnit,
        Individual,
        IndividualMembership,
        OperatorLifecycleRequest,
        OperatorToken,
        Persona,
        PersonaMembership,
        VisitorPreference,
        VisitorSignUpFlow,
        VisitorWithdrawalFlowEvent,
      ],
    )

    columns = warnings.pluck(:column)

    assert_not_includes columns, "operator_identity_id"
    assert_not_includes columns, "user_id"
    assert_not_includes columns, "visitor_identity_id"
    assert_not_includes columns, "requested_by_operator_id"
    assert_not_includes columns, "client_identity_id"
    assert_not_includes columns, "blocked_avatar_id"
    assert_not_includes columns, "blocker_avatar_id"
    assert_not_includes columns, "muted_avatar_id"
    assert_not_includes columns, "muter_avatar_id"
    assert_not_includes columns, "[\"parent_id\", \"bureau_id\"]"
    assert_not_includes columns, "[\"parent_id\", \"company_id\"]"
    assert_not_includes columns, "[\"parent_id\", \"enterprise_id\"]"
    assert_not_includes columns, "[\"bureau_unit_id\", \"bureau_id\"]"
    assert_not_includes columns, "[\"company_unit_id\", \"company_id\"]"
    assert_not_includes columns, "[\"enterprise_unit_id\", \"enterprise_id\"]"
    %w(
      approved_by_agent_id granted_by_agent_id revoked_by_agent_id
      approved_by_individual_id granted_by_individual_id revoked_by_individual_id
      approved_by_persona_id granted_by_persona_id revoked_by_persona_id
    ).each { |col| assert_not_includes columns, col }
    assert_not_includes columns, "token_id"
    assert_not_includes columns, "status_id"
    assert_not_includes columns, "user_token_kind_id"
    assert_not_includes columns, "user_token_status_id"
    assert_not_includes columns, "client_id"
    assert_not_includes columns, "from_status_id"
    assert_not_includes columns, "to_status_id"
    assert_not_includes columns, "staff_token_kind_id"
    assert_not_includes columns, "staff_token_status_id"
    assert_not_includes columns, "chronicle_id"
    assert_not_includes columns, "visitor_id"
  end

  test "missing dependent destroy checker accepts alternate dependent associations on operator" do
    checker = DbConsistencyCheckers::MissingDependentDestroyChecker.new

    warnings = checker.check([Operator])

    columns = warnings.pluck(:column)

    assert_not_includes columns, "operator_emails/staff_id"
    assert_not_includes columns, "operator_passkeys/staff_id"
    assert_not_includes columns, "operator_secret_credentials/staff_id"
    assert_not_includes columns, "operator_telephones/staff_id"
  end

  test "missing unique index checker ignores primary key uniqueness validations" do
    checker = DbConsistencyCheckers::MissingUniqueIndexChecker.new

    assert_empty checker.check([ClientSecretCredentialKind])
  end

  test "unique index checker recognizes public id validators from shared concerns" do
    checker = DbConsistencyCheckers::UniqueIndexChecker.new

    warnings = checker.check([VisitorEmail])

    assert_not_includes warnings.pluck(:column), "public_id"
  end

  test "unique index checker recognizes blind index uniqueness validators" do
    checker = DbConsistencyCheckers::UniqueIndexChecker.new

    warnings = checker.check(
      [
        ClientEmail,
        ClientTelephone,
        OperatorEmail,
        OperatorTelephone,
        VisitorEmail,
        VisitorTelephone,
      ],
    )

    assert_not_includes warnings.pluck(:column), "address_digest"
    assert_not_includes warnings.pluck(:column), "number_digest"
  end

  test "unique index checker recognizes one to one session and ceremony identifiers" do
    checker = DbConsistencyCheckers::UniqueIndexChecker.new

    warnings = checker.check(
      [
        AppPreference,
        ClientEmailCeremonyTransaction,
        ClientStepUpSession,
        ClientToken,
        ComPreference,
        OperatorEmailCeremonyTransaction,
        OperatorStepUpSession,
        OperatorToken,
        OrgPreference,
        VisitorEmailCeremonyTransaction,
        VisitorStepUpSession,
        VisitorToken,
      ],
    )

    columns = warnings.pluck(:column)

    assert_not_includes columns, "dbsc_session_id"
    assert_not_includes columns, "grant_jti"
    assert_not_includes columns, "result_jti"
    assert_not_includes columns, "transaction_id"
    assert_not_includes columns, "user_token_id"
    assert_not_includes columns, "staff_token_id"
    assert_not_includes columns, "visitor_token_id"
  end

  test "unique index checker recognizes collective membership and dpop validators" do
    checker = DbConsistencyCheckers::UniqueIndexChecker.new

    warnings = checker.check(
      [
        AgentMembership,
        ClientDpopProofState,
        CompanyUnit,
        IndividualMembership,
        OperatorDpopProofState,
        PersonaMembership,
        VisitorDpopProofState,
        EnterpriseUnit,
      ],
    )

    columns = warnings.pluck(:column)

    assert_not_includes columns, "agent_id"
    assert_not_includes columns, "individual_id"
    assert_not_includes columns, "persona_id"
    assert_not_includes columns, "jti"
    assert_not_includes columns, "nonce"
    assert_not_includes columns, "bureau_id+id"
    assert_not_includes columns, "company_id+id"
    assert_not_includes columns, "enterprise_id+id"
  end

  test "missing index find by checker accepts digest-backed lookup helpers" do
    checker = DbConsistencyCheckers::MissingIndexFindByChecker.new

    assert_empty checker.check(
      [
        ClientEmail,
        ClientTelephone,
        OperatorEmail,
        OperatorTelephone,
        VisitorEmail,
        VisitorTelephone,
      ],
    )
  end

  test "length checker accepts oidc client identifiers on connection and token models" do
    checker = DbConsistencyCheckers::LengthConstraintChecker.new

    assert_empty checker.check(
      [
        ClientOidcConnection,
        ClientToken,
        OperatorOidcConnection,
        OperatorToken,
        VisitorOidcConnection,
        VisitorToken,
      ],
    )
  end

  test "redundant index checkers accept the remaining prefix indexes after cleanup" do
    checker = DbConsistencyCheckers::RedundantIndexChecker.new
    unique_checker = DbConsistencyCheckers::RedundantUniqueIndexChecker.new

    models = [
      AvatarAssignment,
      AvatarMoniker,
      AvatarRolePermission,
      BureauUnitClosure,
      ChronicleVisibility,
      ClientOidcConnection,
      ClientSignUpFlow,
      CompanyUnitClosure,
      CoreAppClientBridge,
      CoreComVisitorBridge,
      CoreOrgOperatorBridge,
      EmailOccurrence,
      EnterpriseUnitClosure,
      HandleAssignment,
      IpOccurrence,
      JwtOccurrence,
      OperatorOidcConnection,
      TelephoneOccurrence,
      VisitorOidcConnection,
      VisitorSignUpFlow,
    ]

    assert_empty checker.check(models)
    assert_empty unique_checker.check(models)
  end
end
