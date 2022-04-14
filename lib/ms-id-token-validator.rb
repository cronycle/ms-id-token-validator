require "net/http/persistent"
require "jwt"
require "active_support/all"

module MsIdToken
  class BadIdTokenFormat < StandardError; end

  class BadIdTokenHeaderFormat < StandardError; end

  class BadIdTokenPayloadFormat < StandardError; end

  class UnableToFetchMsConfig < StandardError; end

  class UnableToFetchMsCerts < StandardError; end

  class BadPublicKeysFormat < StandardError; end

  class UnableToFindMsCertsUri < StandardError; end

  class InvalidAudience < StandardError; end

  class IdTokenExpired < StandardError; end

  class IdTokenNotYetValid < StandardError; end

  class Validator
    MS_CONFIG_URI = "https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration".freeze
    CACHED_CERTS_EXPIRY = 3600
    TOKEN_TYPE = "JWT".freeze
    TOKEN_ALGORITHM = "RS256".freeze

    def test 
      id_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImJXOFpjTWpCQ25KWlMtaWJYNVVRRE5TdHZ4NCJ9.eyJ2ZXIiOiIyLjAiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vOTE4ODA0MGQtNmM2Ny00YzViLWIxMTItMzZhMzA0YjY2ZGFkL3YyLjAiLCJzdWIiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFJdUlBQk5TNHhFaEppOVlUczhobW5rIiwiYXVkIjoiNTIyZmEyMTQtNGQ2OC00ODRjLWJiZWYtMjFjZGI0ZmFlZDZhIiwiZXhwIjoxNjQ5ODQyNDQ0LCJpYXQiOjE2NDk3NTU3NDQsIm5iZiI6MTY0OTc1NTc0NCwibmFtZSI6IlBpeXVzaCBDcm9ueWNsZSIsInByZWZlcnJlZF91c2VybmFtZSI6InBpeXVzaEBjcm9ueWNsZS5jb20iLCJvaWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtYmJlOS1lYTU0YmFkYzA4MGUiLCJlbWFpbCI6InBpeXVzaEBjcm9ueWNsZS5jb20iLCJ0aWQiOiI5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJub25jZSI6IjY3ODkxMCIsImFpbyI6IkRSUip4UVFCRHZxSVdUSWlQcVpFeHh4Nmc3Q2t1YjVlODE0U2VVSFBLQzUxdWxrV1R4TzdjcFRYRSF6alhNQW13Qkk3UkdiaTUxV29JMW04eU1qR0NDeGdtQklMY0JxQXlpSGQzWXhVZEZ2Kkd3Q0FxWnRJSnNGeGRndzJPM3k3ZWNpdW0hNEVrKkl5NVRNUTRtYnA1UzAkIn0.UDMb0MKF6HUqD_7BFccFtaIF_iZRqgTZMHIHEpSnL6hb8LC5_gkseVUhfkkGVMqv-tixtyVBg1BSa-dwThxod7KDMCMJVwr2AhJ50_fNO_pX2N3Oj3va6AobvVohQMfUSWXpAXV0Lm8vnSE8eVdNaQweoEuJkxkWzc5FrcYatL7UqFAWooGYBfVEiDWpY15pq8MWUmnGPgpbhLQqVbV2MWre9zyDPeHQE6cLomaS9bEz4b2r23M3DHknO9wXgYO42dCUCdQardYPdw8qhsONlbKmvRAlmq1z4aEs-5FY19iEGOafO9bS0wIITqnoSg2Ymn65WUCont9o_z6cG9d6DQ"
      audience = "522fa214-4d68-484c-bbef-21cdb4faed6a"
      check(id_token, audience)
    end

    def initialize(options = {})
      @cached_certs_expiry = options.fetch(:expiry, CACHED_CERTS_EXPIRY)
    end

    def check(id_token, audience)
      encoded_header, encoded_payload, signature = id_token.split(".")

      raise BadIdTokenFormat if encoded_payload.nil? || signature.nil?

      # header = JSON.parse(Base64.decode64(encoded_header), symbolize_names: true)
      
      # signature verification with microsoft public keys
      jwks = ms_public_keys
      decoded_token = JWT.decode(id_token, nil, true, { algorithms: [TOKEN_ALGORITHM], jwks: jwks})
      
      # validate header and payload
      header = decoded_token[1].deep_symbolize_keys
      verify_header(header)
      payload = decoded_token[0].deep_symbolize_keys
      verify_payload(payload, audience)

      payload
    end

    private

    def verify_header(header)
      valid_header = header[:typ] == TOKEN_TYPE && header[:alg] == TOKEN_ALGORITHM

      # "x5t" claim is for version 1.0 only
      # valid_header &= !(header["kid"].nil? && header["x5t"].nil?)
      valid_header &= !(header[:kid].nil?)

      raise BadIdTokenHeaderFormat unless valid_header
    end

    def verify_payload(payload, audience)
      if payload[:aud].nil? ||
          payload[:exp].nil? ||
          payload[:nbf].nil? ||
          payload[:sub].nil? ||
          payload[:iss].nil? ||
          payload[:iat].nil? ||
          payload[:tid].nil? ||
          (
           payload[:iss].match(/https:\/\/login\.microsoftonline\.com\/(.+)\/v2\.0/).nil? &&
           payload[:iss].match(/https:\/\/sts\.windows\.net\/(.+)\//).nil?
         )
        raise BadIdTokenPayloadFormat
      end

      raise InvalidAudience if payload[:aud] != audience

      current_time = Time.current.to_i

      raise IdTokenExpired if payload[:exp] < current_time

      raise IdTokenNotYetValid if payload[:nbf] > current_time
    end

    def ms_public_keys
      if @ms_public_keys.nil? || cached_certs_expired?
        @ms_public_keys = fetch_public_keys
        @last_cached_at = Time.current.to_i
      end

      @ms_public_keys
    end

    def fetch_public_keys
      ms_certs_uri = fetch_ms_config[:jwks_uri]

      raise UnableToFindMsCertsUri if ms_certs_uri.nil?

      uri = URI(ms_certs_uri)
      response = Net::HTTP.get_response(uri)

      raise UnableToFetchMsConfig unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body, symbolize_names: true)
    end

    def fetch_ms_config
      uri = URI(MS_CONFIG_URI)
      response = Net::HTTP.get_response(uri)

      raise UnableToFetchMsConfig unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body, symbolize_names: true)
    end

    def cached_certs_expired?
      !(@last_cached_at.is_a?(Integer) && @last_cached_at + @cached_certs_expiry >= Time.current.to_i)
    end
  end
end
