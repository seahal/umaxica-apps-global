import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { IdentityLink } from "@/types/identity";

type ScheduleSection = {
  title: string;
  ack_label: string;
  submit_label: string;
  acknowledged: boolean;
  action: string;
  errors: string[];
};

type DeactivateSection = {
  title: string;
  ack_label: string;
  submit_label: string;
  confirm: string;
  action: string;
  errors: string[];
};

type Props = {
  title: string;
  already_deactivated: boolean;
  already_deactivated_message: string;
  recovery_link: IdentityLink;
  schedule: ScheduleSection;
  deactivate: DeactivateSection | null;
};

export default function WithdrawalNew({
  title,
  already_deactivated: alreadyDeactivated,
  already_deactivated_message: alreadyDeactivatedMessage,
  recovery_link: recoveryLink,
  schedule,
  deactivate,
}: Props) {
  const [ackSchedule, setAckSchedule] = useState(schedule.acknowledged);
  const [ackDeactivate, setAckDeactivate] = useState(false);
  const { confirm, dialog } = useConfirm();

  if (alreadyDeactivated) {
    return (
      <section>
        <h1>{title}</h1>
        <p>{alreadyDeactivatedMessage}</p>
        <Link href={recoveryLink.href}>{recoveryLink.label}</Link>
      </section>
    );
  }

  return (
    <section>
      <h1>{title}</h1>

      <section>
        <h2>{schedule.title}</h2>

        {schedule.errors.map((message) => (
          <p
            key={message}
            role="alert"
          >
            {message}
          </p>
        ))}

        <form
          onSubmit={(event) => {
            event.preventDefault();
            router.get(schedule.action, { ack_schedule_purge: ackSchedule ? "1" : "0" });
          }}
        >
          <input
            id="ack_schedule_purge"
            type="checkbox"
            checked={ackSchedule}
            onChange={(event) => setAckSchedule(event.target.checked)}
          />
          <label htmlFor="ack_schedule_purge">{schedule.ack_label}</label>
          <button type="submit">{schedule.submit_label}</button>
        </form>
      </section>

      {deactivate ? (
        <section>
          <h2>{deactivate.title}</h2>

          {deactivate.errors.map((message) => (
            <p
              key={message}
              role="alert"
            >
              {message}
            </p>
          ))}

          <form
            onSubmit={(event) => {
              event.preventDefault();
              confirm(
                { message: deactivate.confirm, confirmLabel: deactivate.submit_label },
                () => {
                  router.patch(deactivate.action, {
                    data: { ack_deactivate_today: ackDeactivate ? "1" : "0" },
                  });
                },
              );
            }}
          >
            <input
              id="ack_deactivate_today"
              type="checkbox"
              checked={ackDeactivate}
              onChange={(event) => setAckDeactivate(event.target.checked)}
            />
            <label htmlFor="ack_deactivate_today">{deactivate.ack_label}</label>
            <button type="submit">{deactivate.submit_label}</button>
          </form>
        </section>
      ) : null}
      {dialog}
    </section>
  );
}
