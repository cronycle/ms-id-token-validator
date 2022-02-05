require "spec_helper"
require "pry"
require "timecop"

RSpec.describe MsIdToken::Validator do
  it "has a version number" do
    expect(MsIdToken::Validator::VERSION).not_to be nil
  end

  let(:validator) { described_class.new(options) }
  let(:options) { {} }
  let(:aud) { "123456789" }

  context "with invalid id token format" do
    subject { validator.check(id_token, aud) }
    let(:id_token) { "dummy_token" }

    it do
      expect { subject }.to raise_error(MsIdToken::BadIdTokenFormat)
    end
  end

  context "with valid id token format" do
    let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:header) { {typ: "JWT", alg: "RS256", kid: "123456"} }
    let(:exp) { Time.current + 3600 }
    let(:nbf) { Time.current - 3600 }
    let(:tid) { "1abc-2cdf-5678-abc-abc" }
    let(:iss) { "https://login.microsoftonline.com/#{tid}/v2.0" }
    let(:payload) {
      {aud: aud,
       exp: exp,
       nbf: nbf,
       sub: "dummysub",
       iss: iss,
       tid: tid,
       iat: Time.current}
    }

    let(:id_token) do
      id_token = JSON::JWT.new(payload)
      id_token.kid = private_key.to_jwk.thumbprint
      id_token = id_token.sign(private_key, :RS256)
      id_token.to_s
    end

    before do
      expect(validator).to receive(:ms_public_keys).and_return(private_key.to_jwk)
    end

    context "with invalid id token" do
      context "id token has expired" do
        subject { validator.check(id_token, aud) }
        let(:exp) { Time.current - 1 }

        it do
          expect { subject }.to raise_error(MsIdToken::IdTokenExpired)
        end
      end

      context "id token is mismatched" do
        it do
          header, encoded_payload, signature = id_token.split(".")
          fake_payload = JSON.parse(Base64.decode64(encoded_payload), symbolize_names: true)
          fake_payload[:sub] = "change-sub"
          fake_id_token = [header, Base64.strict_encode64(fake_payload.to_json), signature].join(".")

          expect {
            validator.check(fake_id_token, aud)
          }.to raise_error(JSON::JWS::VerificationFailed)
        end
      end
    end

    context "with valid id token" do
      subject { validator.check(id_token, aud) }
      it { is_expected.to eq(payload) }
    end
  end

  context "caching certs" do
    context "cache not available yet" do
      it do
        expect(validator).to receive(:fetch_public_keys)
        validator.send(:ms_public_keys)
      end
    end

    context "cache is expired" do
      let(:options) { {expiry: 1800} }
      it do
        expect(validator).to receive(:fetch_public_keys).and_return(double(:public_key)).exactly(2).times

        Timecop.freeze(Time.current - 1801) do
          validator.send(:ms_public_keys)
        end

        validator.send(:ms_public_keys)
      end
    end

    context "cache is still valid" do
      let(:options) { {expiry: 1800} }
      it do
        expect(validator).to receive(:fetch_public_keys).and_return(double(:public_key)).exactly(1).times

        Timecop.freeze(Time.current - 1790) do
          validator.send(:ms_public_keys)
        end

        validator.send(:ms_public_keys)
      end
    end
  end
end
