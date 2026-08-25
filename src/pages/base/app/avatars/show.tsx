import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";

type Props = {
  title: string;
  moniker: string;
  handle: string | null;
  // The server omits the link when the actor may not edit the avatar.
  edit: { label: string; href: string } | null;
};

export default function AvatarShow({ moniker, handle, edit }: Props) {
  return (
    <Page
      title={moniker}
      {...(handle === null ? {} : { description: handle })}
      width="narrow"
      {...(edit === null
        ? {}
        : {
            actions: (
              <ButtonLink
                href={edit.href}
                variant="secondary"
                size="sm"
                inertia
              >
                {edit.label}
              </ButtonLink>
            ),
          })}
    />
  );
}
