import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  reset_unavailable: string;
  toggle_title: string;
  state_label: string;
  back_link: IdentityLink;
  error: string | null;
};

export default function MfaChallengeShow({
  title,
  reset_unavailable: resetUnavailable,
  toggle_title: toggleTitle,
  state_label: stateLabel,
  back_link: backLink,
  error,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      {error ? <p role="alert">{error}</p> : null}

      <p>{resetUnavailable}</p>

      <div>
        <span>{toggleTitle}</span>
        <span>{stateLabel}</span>
      </div>
    </section>
  );
}
