type PrivacyRequest = {
  status_label: string;
  received_label: string;
  response_due_label: string;
};

type Props = {
  title: string;
  empty_message: string;
  privacy_request: PrivacyRequest | null;
};

export default function PrivacyErasureStatusShow({
  title,
  empty_message: emptyMessage,
  privacy_request: privacyRequest,
}: Props) {
  return (
    <section>
      <h1>{title}</h1>

      {privacyRequest ? (
        <>
          <p>{privacyRequest.status_label}</p>
          <p>{privacyRequest.received_label}</p>
          <p>{privacyRequest.response_due_label}</p>
        </>
      ) : (
        <p>{emptyMessage}</p>
      )}
    </section>
  );
}
