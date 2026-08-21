// The screen an operator reaches when step-up is required but no method is configured yet.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";

export type OrgVerificationSetupProps = {
  title: string;
  description: string;
  back_link: { label: string; href: string } | null;
  methods: { key: string; label: string; href: string }[];
};

export default function OrgVerificationSetup({
  title,
  description,
  back_link: backLink,
  methods,
}: OrgVerificationSetupProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <NavList items={methods} />
    </Page>
  );
}
