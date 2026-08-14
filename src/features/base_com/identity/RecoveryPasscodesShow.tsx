// Replaces the `shared/recovery_passcodes/show` partial for the base/com surface.
//
// The passcodes are the one-time reveal the server just consumed for this owner; the page shows
// them once and holds nothing else.

export type RecoveryPasscodesShowProps = {
  title: string;
  description: string;
  one_time_notice: string;
  inventory_notice: string;
  missing_message: string;
  passcodes: string[];
  back_link: { label: string; href: string };
};

export default function RecoveryPasscodesShow({
  title,
  description,
  one_time_notice: oneTimeNotice,
  inventory_notice: inventoryNotice,
  missing_message: missingMessage,
  passcodes,
  back_link: backLink,
}: RecoveryPasscodesShowProps) {
  return (
    <section>
      <h1>{title}</h1>

      {passcodes.length > 0 ? (
        <>
          <p>{description}</p>
          <p>{oneTimeNotice}</p>
          <p>{inventoryNotice}</p>
          <ul>
            {passcodes.map((passcode) => (
              <li key={passcode}>
                <code>{passcode}</code>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <p>{missingMessage}</p>
      )}

      {/* Cross-host destination, so a document visit rather than an Inertia visit. */}
      <a href={backLink.href}>{backLink.label}</a>
    </section>
  );
}
