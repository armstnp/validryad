# Validryad

A Ruby data validation tool, built to lean on dry-rb.

Other validation tools are either focused on:
- binding to user input forms,
- recreating or supplementing ActiveRecord validations, or
- supplying user-friendly error messages instead of programmatic error codes

This is a design gap I'm interested in filling, as it fits my mental model for many validation cases, and is especially suitable for APIs in a way other Ruby validation libraries are not.

The aim, then, is for **Validryad** to be a validation library that supplies programmatically useful validation errors, while performing some minimal coercion and alteration of the data as useful.

The library draws on the existing [dry-validation](https://dry-rb.org/gems/dry-validation/1.5/) library for design inspiration, while making some concretely different decisions:
- Error messages are programmatic, not user-based
- Validation is not tailored towards hashes alone, but suited for any combination of values, including hashes and arrays

## Installation

_(NB: This gem is not yet published)_

Add this line to your application's Gemfile:

```ruby
gem 'validryad'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install validryad

## Usage

### Create a contract

```ruby
class EndpointContract < Validryad::Contract
  specify(
    hash(
      mandatory: {
        url: typed(T::String), # Using dry-types loaded in module T!
        ip: typed(T::String) >
            matching(ip_re) & rule(error: :low_range) { _1.split('.').first.to_i >= 100 }
      },
      optional: {
        rate_limit: typed(T::Coercible::Decimal) > gt(0)
      }
    )
  )
end
```

### Calling a contract

```ruby
EndpointContract.call({url: 'abc.com', ip: '123.456.789.012'})
# => Success({:url=>"abc.com", :ip=>"123.456.789.012"})

EndpointContract.call({url: 'abc.com', ip: '99.456.789.012'})
# => Failure([[:low_range, [:ip]]])

EndpointContract.call({rate_limit: -2})
# Failure([[[:not_gt, 0], [:rate_limit]], [[:missing_key, :url], []], [[:missing_key, :ip], []]])
```

Success values are the validated values, with the right-most validation's value in cases of
coercing validations, e.g. the coercion of `rate_limit` above to a `BigDecimal`.

Failure values are an array of pairs: an error message, and the path of the invalid value being
addressed.
- In the examples above, `[:low_range, [:ip]]` is an error that tells us that the value in the path
  `[:ip]` was invalid for the reason `:low_range`.
- Other errors may be more complex, such as `[:not_gt, 0]`, which indicates that the value was not
  greater than the expected minimum value, 0.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/armstnp/validryad.

The maintainer makes no promises regarding response times, but will make effort to be respectful of the time put in to suggestions and proposed changes.

Forking is an option! The code should be compact enough to be something you can copy into your own project if so desired, instead of loading it as a gem.

