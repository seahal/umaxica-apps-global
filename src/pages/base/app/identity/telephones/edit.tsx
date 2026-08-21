import { router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import type { IdentityDestructiveAction, IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  number: string;
  delete: IdentityDestructiveAction;
  cancel_link: IdentityLink;
};

export default function TelephoneEdit({
  title,
  number,
  delete: destroy,
  cancel_link: cancelLink,
}: Props) {
  const { confirm, dialog } = useConfirm();

  const remove = () => {
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => router.delete(destroy.url),
    );
  };

  return (
    <Page
      title={title}
      description={number}
      width="narrow"
    >
      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="danger"
          onPress={remove}
        >
          {destroy.label}
        </Button>

        <ButtonLink
          href={cancelLink.href}
          variant="secondary"
          inertia
        >
          {cancelLink.label}
        </ButtonLink>
      </div>
      {dialog}
    </Page>
  );
}
