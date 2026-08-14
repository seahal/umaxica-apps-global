import type { IdentityLink } from "@/types/identity";

type ActivityRow = {
  event_id: number;
  occurred_at: string;
  event_label: string;
  ip_address: string;
  user_agent_summary: string;
  login_method: string;
  context_text: string;
};

type Props = {
  title: string;
  description: string;
  empty_message: string;
  back_link: IdentityLink;
  table_headings: {
    occurred_at: string;
    event: string;
    ip_address: string;
    device: string;
    login_method: string;
    context: string;
  };
  activities: ActivityRow[];
};

export default function ActivitiesIndex({
  title,
  description,
  empty_message: emptyMessage,
  back_link: backLink,
  table_headings: headings,
  activities,
}: Props) {
  return (
    <section>
      <a href={backLink.href}>{backLink.label}</a>

      <h1>{title}</h1>
      <p>{description}</p>

      {activities.length === 0 ? (
        <p>{emptyMessage}</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>{headings.occurred_at}</th>
              <th>{headings.event}</th>
              <th>{headings.ip_address}</th>
              <th>{headings.device}</th>
              <th>{headings.login_method}</th>
              <th>{headings.context}</th>
            </tr>
          </thead>
          <tbody>
            {activities.map((activity, index) => (
              <tr key={`${activity.event_id}-${index}`}>
                <td>{activity.occurred_at}</td>
                <td>
                  {activity.event_label} ({activity.event_id})
                </td>
                <td>{activity.ip_address}</td>
                <td>{activity.user_agent_summary}</td>
                <td>{activity.login_method}</td>
                <td>
                  <code>{activity.context_text}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
