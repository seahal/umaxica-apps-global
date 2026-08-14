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
    <section>
      <h1>{title}</h1>

      {privacyRequest ? (
        <>
          <p>
            {privacyRequest.status_term}: {privacyRequest.status_label}
          </p>
          <p>
            {privacyRequest.received_term}: {privacyRequest.received_at}
          </p>
          <p>
            {privacyRequest.response_due_term}: {privacyRequest.response_due_at}
          </p>
        </>
      ) : (
        <p>{emptyMessage}</p>
      )}
    </section>
  );
}
