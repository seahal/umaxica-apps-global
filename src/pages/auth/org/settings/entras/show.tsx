// The read-only view of the operator's Microsoft Entra ID connection state.
type EntraLink = {
  label: string;
  href: string;
};

export type OrgEntraSettingsShowProps = {
  title: string;
  heading: string;
  back_link: EntraLink;
  status: string;
  edit_link: EntraLink;
};

export default function OrgEntraSettingsShow({
  heading,
  back_link: backLink,
  status,
  edit_link: editLink,
}: OrgEntraSettingsShowProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{heading}</h3>
        <p>{status}</p>
        <a href={editLink.href}>{editLink.label}</a>
      </div>
    </section>
  );
}
