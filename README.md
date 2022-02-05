# MsIdTokenValidator

This library is provided to validate id token from Microsoft Oauth2.

Inspired from the [Google ID Token](https://github.com/google/google-id-token)

### Disclaimer
I am entirely not affiliated with Microsoft, the code is provided as-is and no warranty.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ms-id-token-validator'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ms-id-token-validator

## Usage

```ruby
validator = MsIdToken::Validator.new

begin
  # audience is possibly the Application Client ID
  payload = validator.check(id_token, audience)
rescue MsIdToken::IdTokenExpired => ex
  puts 'Id token is expired'
end

```

By default, the public keys fetched from Microsoft are cached in one hour. Microsoft [state that](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-tokens) their public key should be updated within 24 hours, so our default value is more than enough.

To change the cached expiry, for example, 6 hours, we can pass the value at the time creating the validator.

```ruby
validator = MsIdToken::Validator.new({expiry: 6 * 3600})
```

## References

[Certificate credentials for application authentication](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials)

[Validate an Exchange identity token](https://docs.microsoft.com/en-us/outlook/add-ins/validate-an-identity-token)

[Azure Active Directory v2.0 tokens reference](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-tokens)

[Azure AD token reference](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-token-and-claims)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/QQism/ms-id-token-validator. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
