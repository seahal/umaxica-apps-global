import type { IdentityLink } from "@/types/identity";

type SessionRecord = {
  public_id: string;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  current: boolean;
  revoke_url: string;
};

type Props = {
  title: string;
  session: SessionRecord;
  back_link: IdentityLink;
};

export default function SessionShow({ title, session, back_link: backLink }: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>

      <dl>
        <dt>Session</dt>
        <dd>{session.public_id}</dd>
        <dt>Kind</dt>
        <dd>{session.kind}</dd>
        <dt>Binding</dt>
        <dd>{session.binding}</dd>
        <dt>Last activity</dt>
        <dd>{session.last_activity}</dd>
        <dt>Created</dt>
        <dd>{session.created}</dd>
        <dt>Refresh expires</dt>
        <dd>{session.refresh_expires}</dd>
      </dl>
    </section>
  );
}
