// The step-up entry screen: pick a verification method.
export type OrgVerificationEntryProps = {
  title: string;
  section_title: string;
  section_description: string;
  notice: string | null;
  no_methods: string | null;
  methods: { key: string; label: string; href: string }[];
};

export default function OrgVerificationEntry({
  title,
  section_title: sectionTitle,
  section_description: sectionDescription,
  notice,
  no_methods: noMethods,
  methods,
}: OrgVerificationEntryProps) {
  return (
    <section className="mx-auto flex w-full max-w-2xl flex-col gap-6 p-6">
      <h1>{title}</h1>

      {notice ? <p role="status">{notice}</p> : null}

      <div>
        <h2>{sectionTitle}</h2>
        <p>{sectionDescription}</p>

        {noMethods ? <p>{noMethods}</p> : null}

        {methods.map((method) => (
          <div key={method.key}>
            <a href={method.href}>{method.label}</a>
          </div>
        ))}
      </div>
    </section>
  );
}
