// Replaces `app/views/base/com/identity/privacy/erasure/statuses/show.html.erb`.

export type PrivacyErasureStatusShowProps = {
  title: string;
  empty_message: string;
  privacy_request: {
    status_term: string;
    status_label: string;
    received_term: string;
    received_at: string | null;
    response_due_term: string;
    response_due_at: string | null;
  } | null;
};

export default function PrivacyErasureStatusShow({
  title,
  empty_message: emptyMessage,
  privacy_request: privacyRequest,
}: PrivacyErasureStatusShowProps) {
  return (
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      {privacyRequest ? (
        <dl className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4 text-sm">
          <div className="flex flex-col gap-1 sm:flex-row sm:gap-2">
            <dt className="font-medium text-fg-muted sm:w-48">{privacyRequest.status_term}</dt>
            <dd className="text-fg">{privacyRequest.status_label}</dd>
          </div>
          <div className="flex flex-col gap-1 sm:flex-row sm:gap-2">
            <dt className="font-medium text-fg-muted sm:w-48">{privacyRequest.received_term}</dt>
            <dd className="text-fg">{privacyRequest.received_at}</dd>
          </div>
          <div className="flex flex-col gap-1 sm:flex-row sm:gap-2">
            <dt className="font-medium text-fg-muted sm:w-48">
              {privacyRequest.response_due_term}
            </dt>
            <dd className="text-fg">{privacyRequest.response_due_at}</dd>
          </div>
        </dl>
      ) : (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      )}
    </section>
  );
}
