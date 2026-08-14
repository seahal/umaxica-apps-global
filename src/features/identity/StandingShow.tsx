// The account standing screen. Each decision arrives humanised and already scoped to the actor by
// the server, so the page never re-derives a level or a reason.
export type StandingDecision = {
  public_id: string;
  kind: string;
  reason: string;
  /** Already-formatted end date, or null when the decision does not expire. */
  ends_at: string | null;
};

export type StandingShowProps = {
  title: string;
  status_label: string;
  decisions: StandingDecision[];
};

export default function StandingShow({
  title,
  status_label: statusLabel,
  decisions,
}: StandingShowProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{statusLabel}</p>

      {decisions.map((decision) => (
        <section
          key={decision.public_id}
          id={`standing-decision-${decision.public_id}`}
        >
          <h2>{decision.kind}</h2>
          <p>{decision.reason}</p>
          {decision.ends_at ? <p>{decision.ends_at}</p> : null}
        </section>
      ))}
    </section>
  );
}
