# typed: false
# frozen_string_literal: true

require "test_helper"

# Candidate rows carry a serialised provider payload, so a row whose payload has
# lost a claim or holds the wrong type is corrupt state, not a missing record.
# Both readers report it as a contract error so the ceremony stops rather than
# continuing with a half-read candidate.
class IdentitySocialCeremonyCandidateStoreFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a candidate row whose payload has lost a claim is reported as a contract error" do
    broken = ->(*, **) { raise KeyError, "key not found: \"issuer\"" }

    IdentitySocialCeremonyCandidate.stub(:find_active_by_ref!, broken) do
      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyCandidateStore.fetch!("candidate-ref")
        end

      assert_match(/candidate is invalid/, error.message)
    end
  end

  test "a candidate row whose payload holds the wrong type is reported the same way" do
    broken = ->(*, **) { raise TypeError, "no implicit conversion" }

    IdentitySocialCeremonyCandidate.stub(:find_active_by_ref!, broken) do
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.fetch!("candidate-ref")
      end
    end
  end
end
