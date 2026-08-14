type SwitcherSelection = {
  account_public_id: string | null;
  organization_public_id: string | null;
  organization_unit_public_id: string | null;
  avatar_public_id: string | null;
};

type SwitcherCandidate = {
  account_public_id: string | null;
  organization_public_id: string | null;
  avatar_public_id: string | null;
};

type Props = {
  title: string;
  current: SwitcherSelection | null;
  candidates: SwitcherCandidate[];
  // Present only when a switch attempt was rejected.
  error: string | null;
};

export default function SwitcherShow({ title, current, candidates, error }: Props) {
  return (
    <section>
      <h1>{title}</h1>

      <p>Signed in</p>

      {error ? <p role="alert">{error}</p> : null}

      <section>
        <h2>Current context</h2>
        {current ? (
          <dl>
            <dt>Account</dt>
            <dd>{current.account_public_id}</dd>
            <dt>Organization</dt>
            <dd>{current.organization_public_id}</dd>
            <dt>Organization unit</dt>
            <dd>{current.organization_unit_public_id}</dd>
            <dt>Avatar</dt>
            <dd>{current.avatar_public_id}</dd>
          </dl>
        ) : (
          <p>No current context.</p>
        )}
      </section>

      <section>
        <h2>Available contexts</h2>
        <ul>
          {candidates.map((candidate) => (
            <li
              key={`${candidate.account_public_id}/${candidate.organization_public_id}/${candidate.avatar_public_id}`}
            >
              account={candidate.account_public_id} organization={candidate.organization_public_id}{" "}
              avatar={candidate.avatar_public_id}
            </li>
          ))}
        </ul>
      </section>
    </section>
  );
}
