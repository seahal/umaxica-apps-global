import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
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
    <Page
      title={title}
      up={backLink}
    >
      <Card>
        <DescriptionList
          items={[
            { term: "Session", description: session.public_id },
            { term: "Kind", description: session.kind },
            { term: "Binding", description: session.binding },
            { term: "Last activity", description: session.last_activity },
            { term: "Created", description: session.created },
            { term: "Refresh expires", description: session.refresh_expires },
          ]}
        />
      </Card>
    </Page>
  );
}
