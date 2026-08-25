// The single-session screen. It is still the scaffold the ERB template carried; the props are the
// finished strings the server sends.
import Page from "@/components/ui/Page";

export type SessionShowProps = {
  title: string;
  heading: string;
  body: string;
};

export default function SessionShow({ heading, body }: SessionShowProps) {
  return (
    <Page
      title={heading}
      description={body}
    />
  );
}
