import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  reset_unavailable: string;
  back_link: IdentityLink;
};

export default function MfaResetShow({
  title,
  reset_unavailable: resetUnavailable,
  back_link: backLink,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>
      <p>{resetUnavailable}</p>
    </section>
  );
}
