require 'net/http'
require 'json/jwt'

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
    MS_CONFIG_URI = 'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration'.freeze
    CACHED_CERTS_EXPIRY = 3600
    TOKEN_TYPE = 'JWT'.freeze
    TOKEN_ALGORITHM = 'RS256'.freeze

    def initialize(options={})
      @cached_certs_expiry = options.fetch(:expiry, CACHED_CERTS_EXPIRY)
    end

    def check(id_token, audience)
      encoded_header, encoded_payload, signature = id_token.split('.')

      raise BadIdTokenFormat if encoded_payload.nil? || signature.nil?

      header = JSON.parse(Base64.decode64(encoded_header), symbolize_names: true)

      public_keys = JSON::JWK::Set.new(ms_public_keys)

      payload = JSON::JWT.decode(id_token, public_keys).symbolize_keys

      verify_payload(payload, audience)

      payload
    end

    private

    def verify_header(header)
      valid_header = header[:typ] == TOKEN_TYPE && header[:alg] == TOKEN_ALGORITHM

      valid_header &= !(header[:kid].nil? && header[:x5t].nil?)

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
