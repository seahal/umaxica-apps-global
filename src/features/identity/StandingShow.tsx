// The account standing screen. Each decision arrives humanised and already scoped to the actor by
// the server, so the page never re-derives a level or a reason.
import Page from "@/components/ui/Page";

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
    <Page
      title={title}
      description={statusLabel}
      width="wide"
    >
      {decisions.map((decision) => (
        <section
          key={decision.public_id}
          id={`standing-decision-${decision.public_id}`}
          className="flex flex-col gap-1 rounded-lg border border-line bg-surface p-4"
        >
          <h2 className="text-lg font-semibold text-fg">{decision.kind}</h2>
          <p className="text-sm text-fg">{decision.reason}</p>
          {decision.ends_at ? <p className="text-sm text-fg-muted">{decision.ends_at}</p> : null}
        </section>
      ))}
    </Page>
  );
}
