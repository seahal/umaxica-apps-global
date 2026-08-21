import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
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
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
    >
      {activities.length === 0 ? (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      ) : (
        <Table>
          <thead>
            <tr>
              <th scope="col">{headings.occurred_at}</th>
              <th scope="col">{headings.event}</th>
              <th scope="col">{headings.ip_address}</th>
              <th scope="col">{headings.device}</th>
              <th scope="col">{headings.login_method}</th>
              <th scope="col">{headings.context}</th>
            </tr>
          </thead>
          <tbody>
            {activities.map((activity, index) => (
              <tr key={`${activity.event_id}-${index}`}>
                <td className="whitespace-nowrap text-fg-muted">{activity.occurred_at}</td>
                <td>
                  {activity.event_label} ({activity.event_id})
                </td>
                <td className="font-mono">{activity.ip_address}</td>
                <td>{activity.user_agent_summary}</td>
                <td>{activity.login_method}</td>
                <td>
                  <code className="text-xs break-all text-fg-muted">{activity.context_text}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Page>
  );
}
