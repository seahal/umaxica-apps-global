import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

// Replaces `app/views/base/com/identity/activities/index.html.erb`. Every cell arrives as finished
// text: localisation and the chronicle formatting stayed on the server.

export type ActivityRow = {
  id: string;
  occurred_at: string;
  event_label: string;
  event_id: string;
  ip_address: string;
  device: string;
  login_method: string;
  context: string;
};

export type ActivityIndexProps = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  empty_message: string;
  columns: {
    occurred_at: string;
    event: string;
    ip_address: string;
    device: string;
    login_method: string;
    context: string;
  };
  activities: ActivityRow[];
};

export default function ActivityIndex({
  title,
  description,
  back_link: backLink,
  empty_message: emptyMessage,
  columns,
  activities,
}: ActivityIndexProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
    >
      {activities.length > 0 ? (
        <Table>
          <thead>
            <tr>
              <th>{columns.occurred_at}</th>
              <th>{columns.event}</th>
              <th>{columns.ip_address}</th>
              <th>{columns.device}</th>
              <th>{columns.login_method}</th>
              <th>{columns.context}</th>
            </tr>
          </thead>
          <tbody>
            {activities.map((activity) => (
              <tr
                key={activity.id}
                className="last:border-0"
              >
                <td>{activity.occurred_at}</td>
                <td>
                  {activity.event_label} ({activity.event_id})
                </td>
                <td>{activity.ip_address}</td>
                <td>{activity.device}</td>
                <td>{activity.login_method}</td>
                <td>
                  <code className="rounded-sm bg-surface-muted px-1 py-0.5 text-xs">
                    {activity.context}
                  </code>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      ) : (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      )}
    </Page>
  );
}
