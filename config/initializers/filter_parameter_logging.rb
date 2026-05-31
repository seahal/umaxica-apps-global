# typed: false
# frozen_string_literal: true

Rails.application.config.filter_parameters += %i(
  passw
  email
  telephone
  birthdate
  secret
  credential
  recovery_code
  otp
  token
  jwt
  authorization
  cookie
  _key
  keyset
  jwk
  jwks
  pem
  der
  certificate
  crypt
  salt
  ssn
  cvv
  cvc
  state
  session_id
  credential_id
  smtp_password
  aws_ses_smtp_password
)
