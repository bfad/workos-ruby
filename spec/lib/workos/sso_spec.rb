# frozen_string_literal: true
# typed: false

require 'securerandom'

describe WorkOS::SSO do
  describe '.authorization_url' do
    context 'with a domain' do
      let(:args) do
        {
          domain: 'foo.com',
          project_id: 'workos-proj-123',
          redirect_uri: 'foo.com/auth/callback',
          state: {
            next_page: '/dashboard/edit',
          },
        }
      end
      it 'returns a valid URL' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url)).to be_a URI
      end

      it 'returns the expected hostname' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url).host).to eq(WorkOS::API_HOSTNAME)
      end

      it 'returns the expected query string' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url).query).to eq(
          'client_id=workos-proj-123&redirect_uri=foo.com%2Fauth%2Fcallback' \
          '&response_type=code&state=%7B%3Anext_page%3D%3E%22%2Fdashboard%2F' \
          'edit%22%7D&domain=foo.com',
        )
      end
    end

    context 'with a provider' do
      let(:args) do
        {
          provider: 'GoogleOAuth',
          project_id: 'workos-proj-123',
          redirect_uri: 'foo.com/auth/callback',
          state: {
            next_page: '/dashboard/edit',
          },
        }
      end
      it 'returns a valid URL' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url)).to be_a URI
      end

      it 'returns the expected hostname' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url).host).to eq(WorkOS::API_HOSTNAME)
      end

      it 'returns the expected query string' do
        authorization_url = described_class.authorization_url(**args)

        expect(URI.parse(authorization_url).query).to eq(
          'client_id=workos-proj-123&redirect_uri=foo.com%2Fauth%2Fcallback' \
          '&response_type=code&state=%7B%3Anext_page%3D%3E%22%2Fdashboard%2F' \
          'edit%22%7D&provider=GoogleOAuth',
        )
      end
    end

    context 'with neither domain or provider' do
      let(:args) do
        {
          project_id: 'workos-proj-123',
          redirect_uri: 'foo.com/auth/callback',
          state: {
            next_page: '/dashboard/edit',
          },
        }
      end
      it 'raises an error' do
        expect do
          described_class.authorization_url(**args)
        end.to raise_error(
          ArgumentError,
          'Either domain or provider is required.',
        )
      end
    end

    context 'with an invalid provider' do
      let(:args) do
        {
          provider: 'Okta',
          project_id: 'workos-proj-123',
          redirect_uri: 'foo.com/auth/callback',
          state: {
            next_page: '/dashboard/edit',
          },
        }
      end
      it 'raises an error' do
        expect do
          described_class.authorization_url(**args)
        end.to raise_error(
          ArgumentError,
          'Okta is not a valid value. `provider` must be in ["GoogleOAuth"]',
        )
      end
    end
  end

  describe '.profile' do
    before do
      WorkOS.key = 'api-key'
    end

    let(:args) do
      {
        code: SecureRandom.hex(10),
        project_id: 'workos-proj-123',
      }
    end

    let(:query) do
      {
        client_id: args[:project_id],
        client_secret: WorkOS.key,
        code: args[:code],
        grant_type: 'authorization_code',
      }
    end
    let(:user_agent) { 'user-agent-string' }
    let(:headers) { { 'User-Agent' => user_agent } }
    before do
      allow(described_class).to receive(:user_agent).and_return(user_agent)
    end

    context 'with a successful response' do
      let(:body) { File.read("#{SPEC_ROOT}/support/profile.txt") }

      before do
        stub_request(:post, 'https://api.workos.com/sso/token').
          with(query: query, headers: headers).
          to_return(status: 200, body: body)
      end

      it 'includes the SDK Version header' do
        described_class.profile(**args)

        expect(a_request(:post, 'https://api.workos.com/sso/token').
          with(query: query, headers: headers)).to have_been_made
      end

      it 'returns a WorkOS::Profile' do
        profile = described_class.profile(**args)

        expect(profile).to be_a(WorkOS::Profile)
      end
    end

    context 'with an unprocessable request' do
      before do
        stub_request(:post, 'https://api.workos.com/sso/token').
          with(query: query, headers: headers).
          to_return(
            headers: { 'X-Request-ID' => 'request-id' },
            status: 422,
            body: { "message": 'some error message' }.to_json,
          )
      end

      it 'raises an exception with request ID' do
        expect do
          described_class.profile(**args)
        end.to raise_error(
          WorkOS::APIError,
          'some error message - request ID: request-id',
        )
      end
    end

    context 'with an expired code' do
      before do
        stub_request(:post, 'https://api.workos.com/sso/token').
          with(query: query).
          to_return(
            status: 201,
            headers: { 'X-Request-ID' => 'request-id' },
            body: {
              message: "The code '01DVX3C5Z367SFHR8QNDMK7V24'" \
                ' has expired or is invalid.',
            }.to_json,
          )
      end

      it 'raises an exception' do
        expect do
          described_class.profile(**args)
        end.to raise_error(
          WorkOS::APIError,
          "The code '01DVX3C5Z367SFHR8QNDMK7V24'" \
          ' has expired or is invalid. - request ID: request-id',
        )
      end
    end
  end
end