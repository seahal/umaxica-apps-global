import Page from "@/components/ui/Page";

type Props = {
  title: string;
  description: string;
};

export default function BillingsIndex({ title, description }: Props) {
  return (
    <Page
      title={title}
      description={description}
    />
  );
}
