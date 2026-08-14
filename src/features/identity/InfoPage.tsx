// A read-only identity screen: a heading, some finished paragraphs and a way back.
import { Link } from "@inertiajs/react";

export type InfoPageProps = {
  title: string;
  paragraphs: string[];
  back_link: { label: string; href: string };
};

export default function InfoPage({ title, paragraphs, back_link: backLink }: InfoPageProps) {
  return (
    <section>
      <h1>{title}</h1>
      {paragraphs.map((paragraph) => (
        <p key={paragraph}>{paragraph}</p>
      ))}

      <div>
        <Link href={backLink.href}>{backLink.label}</Link>
      </div>
    </section>
  );
}
