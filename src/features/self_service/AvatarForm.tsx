// The avatar create/update form. The server sends the action URL, the HTTP verb the route expects
// and every label already translated, so the component only binds fields and reports errors.
import { useForm } from "@inertiajs/react";
import type { SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
import TextField from "@/components/ui/TextField";

export type AvatarFormProps = {
  title: string;
  heading: string;
  action: string;
  method: "post" | "patch";
  submit_label: string;
  moniker: { label: string; value: string; maxlength: number };
  // Present only on creation: the handle is immutable once the avatar exists.
  handle: { label: string; value: string; maxlength: number } | null;
};

export default function AvatarForm({
  title,
  heading,
  action,
  method,
  submit_label: submitLabel,
  moniker,
  handle,
}: AvatarFormProps) {
  const form = useForm({
    avatar: { moniker: moniker.value, handle: handle ? handle.value : "" },
  });
  const { data, setData, errors, processing } = form;

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (method === "post") {
      form.post(action);
    } else {
      form.patch(action);
    }
  };

  return (
    <section
      aria-label={title}
      className="flex flex-col gap-6"
    >
      <h1 className="text-2xl font-bold text-fg">{heading}</h1>

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <TextField
          id="avatar_moniker"
          label={moniker.label}
          name="avatar[moniker]"
          isRequired
          maxLength={moniker.maxlength}
          value={data.avatar.moniker}
          onChange={(value) => setData("avatar", { ...data.avatar, moniker: value })}
          {...(errors["avatar.moniker"] === undefined
            ? {}
            : { errorMessage: errors["avatar.moniker"] })}
        />

        {handle ? (
          <TextField
            id="avatar_handle"
            label={handle.label}
            name="avatar[handle]"
            maxLength={handle.maxlength}
            value={data.avatar.handle}
            onChange={(value) => setData("avatar", { ...data.avatar, handle: value })}
            {...(errors["avatar.handle"] === undefined
              ? {}
              : { errorMessage: errors["avatar.handle"] })}
          />
        ) : null}

        <div>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {submitLabel}
          </Button>
        </div>
      </form>
    </section>
  );
}
