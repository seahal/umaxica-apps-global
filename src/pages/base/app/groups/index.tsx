import Page from "@/components/ui/Page";

type GroupsPageProps = {
  title?: string;
};

export default function GroupsIndex({ title = "Groups" }: GroupsPageProps) {
  // The base/app Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <Page
      title={title}
      description="Base App"
      width="wide"
    >
      <p className="max-w-prose text-base leading-7">groups</p>
    </Page>
  );
}
