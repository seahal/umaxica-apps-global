// The entry screen of a sign-in or sign-up ceremony: pick a credential method.
//
// Which methods exist is a server decision, so the list arrives already filtered and each entry
// carries a finished label and a finished URL. When the surface kill switch has suspended the
// ceremony the server sends the notice instead of the methods, and the screen offers no entry point
// into a ceremony the guard would reject anyway.
export type AuthMethodLink = {
  key: string;
  label: string;
  href: string;
};

export type AuthMethodChoiceProps = {
  title: string;
  description: string | null;
  suspended_notice: string | null;
  methods: AuthMethodLink[];
  links: AuthMethodLink[];
};

export default function AuthMethodChoice({
  title,
  description,
  suspended_notice: suspendedNotice,
  methods,
  links,
}: AuthMethodChoiceProps) {
  if (suspendedNotice) {
    return (
      <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
        <div
          role="alert"
          data-test-id="sign-up-suspended"
        >
          <p>{suspendedNotice}</p>
        </div>
      </section>
    );
  }

  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>
      {description ? <p>{description}</p> : null}

      <ul>
        {methods.map((method) => (
          <li
            key={method.key}
            data-test-id="registration-method"
          >
            {/* Document visits: each method starts a ceremony behind its own guards. */}
            <a href={method.href}>{method.label}</a>
          </li>
        ))}
      </ul>

      {links.map((link) => (
        <p key={link.key}>
          <a href={link.href}>{link.label}</a>
        </p>
      ))}
    </section>
  );
}
