import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  name: string;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string;
  last_used_at: string;
  back_link: IdentityLink;
  edit_link: IdentityLink;
};

export default function SecretShow({
  title,
  description,
  name,
  created_at_label: createdAtLabel,
  created_at: createdAt,
  last_used_at_label: lastUsedAtLabel,
  last_used_at: lastUsedAt,
  back_link: backLink,
  edit_link: editLink,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
      width="narrow"
    >
      <Card heading={name}>
        <DescriptionList
          items={[
            { term: createdAtLabel, description: createdAt },
            { term: lastUsedAtLabel, description: lastUsedAt },
          ]}
        />
      </Card>

      <p className="text-sm">
        <TextLink href={editLink.href}>{editLink.label}</TextLink>
      </p>
    </Page>
  );
}
