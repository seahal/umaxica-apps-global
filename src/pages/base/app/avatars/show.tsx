import { Link } from "@inertiajs/react";

type Props = {
  title: string;
  moniker: string;
  handle: string | null;
  // The server omits the link when the actor may not edit the avatar.
  edit: { label: string; href: string } | null;
};

export default function AvatarShow({ title, moniker, handle, edit }: Props) {
  return (
    <section aria-label={title}>
      <h1>{moniker}</h1>

      {handle ? <p>{handle}</p> : null}

      {edit ? <Link href={edit.href}>{edit.label}</Link> : null}
    </section>
  );
}
