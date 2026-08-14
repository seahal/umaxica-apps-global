// The entry screen of the step-up verification ceremony: pick a second factor.
//
// The server decided which factors this actor holds, so `methods` is already filtered and each
// entry carries a finished label and a finished URL. When none is available it sends the notice
// instead, and the screen offers no way into a ceremony the guards would reject.
import type { VerificationMethodLink } from "./types";

export type VerificationEntryProps = {
  title: string;
  heading: string;
  section_title: string;
  description: string;
  methods: VerificationMethodLink[];
  no_methods_notice: string | null;
  notice: string | null;
};

export default function VerificationEntry({
  heading,
  section_title: sectionTitle,
  description,
  methods,
  no_methods_notice: noMethodsNotice,
  notice,
}: VerificationEntryProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{heading}</h1>

      {notice ? <p data-test-id="verification-notice">{notice}</p> : null}

      <div>
        <h2>{sectionTitle}</h2>
        <p>{description}</p>

        {noMethodsNotice ? (
          <p data-test-id="verification-no-methods">{noMethodsNotice}</p>
        ) : (
          <div>
            {methods.map((method) => (
              <div key={method.key}>
                {/* Document visit: each factor ceremony runs behind its own guards. */}
                <a href={method.href}>{method.label}</a>
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
