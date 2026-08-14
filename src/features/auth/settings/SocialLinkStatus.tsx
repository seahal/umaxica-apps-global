// The read-only link status of one social provider on the app surface.
//
// Apple and Google render the same screen, so the copy, the status sentence and every URL arrive
// already resolved from the server and the component only lays them out.
import type { SettingsLink } from "./links";

export type SocialLinkStatusProps = {
  title: string;
  heading: string;
  description: string;
  status: string;
  back_link: SettingsLink;
  edit_link: SettingsLink;
};

export default function SocialLinkStatus({
  heading,
  description,
  status,
  back_link: backLink,
  edit_link: editLink,
}: SocialLinkStatusProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <a href={backLink.href}>{backLink.label}</a>

      <div>
        <h3>{heading}</h3>
        <p>{description}</p>
        <p>{status}</p>
        <a href={editLink.href}>{editLink.label}</a>
      </div>
    </section>
  );
}
