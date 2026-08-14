// The welcome screen a surface shows once, before handing over to its dashboard.
//
// Where "next" goes is a server decision: the welcome sequence resolves it and sends the finished
// destination, so the page never guesses the next step.
import { Link } from "@inertiajs/react";

export type WelcomeShowProps = {
  title: string;
  next_link: { label: string; href: string };
};

export default function WelcomeShow({ title, next_link: nextLink }: WelcomeShowProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>
        <Link href={nextLink.href}>{nextLink.label}</Link>
      </p>
    </section>
  );
}
