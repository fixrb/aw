# Aw

[![Version](https://img.shields.io/github/v/tag/fixrb/aw?label=Version&logo=github)](https://github.com/fixrb/aw/releases)
[![Yard documentation](https://img.shields.io/badge/Yard-documentation-blue.svg?)](https://rubydoc.info/github/fixrb/aw/main)
[![CI](https://github.com/fixrb/aw/workflows/CI/badge.svg?branch=main)](https://github.com/fixrb/aw/actions?query=workflow%3Aci+branch%3Amain)
[![RuboCop](https://github.com/fixrb/aw/workflows/RuboCop/badge.svg?branch=main)](https://github.com/fixrb/aw/actions?query=workflow%3Arubocop+branch%3Amain)
[![License](https://img.shields.io/github/license/fixrb/aw?label=License&logo=github)](https://github.com/fixrb/aw/raw/main/LICENSE.md)

> Aw, fork! 😬

Creates a subprocess to execute a block inside.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "aw"
```

And then execute:

```sh
bundle
```

Or install it yourself as:

```sh
gem install aw
```

## Usage

It executes the block in a subprocess, and returns the result in the current process:

```ruby
Aw.fork! { 6 * 7 } # => 42
```

Of course, it prevents from side effects:

```ruby
arr = ["foo"]

Aw.fork! { arr << "FUU" } # => ["foo", "FUU"]

arr # => ["foo"]
```

Exceptions raised within the block are propagated:

```ruby
Aw.fork! { nil + 1 } # => NoMethodError (undefined method `+' for nil:NilClass)
```

## Contact

* Source code: https://github.com/fixrb/aw

## Versioning

__Aw__ follows [Semantic Versioning 2.0](https://semver.org/).

## License

The [gem](https://rubygems.org/gems/aw) is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

***

<p>
  This project is sponsored by:<br />
  <a href="https://sashite.com/"><img
    src="https://github.com/fixrb/aw/raw/main/img/sashite.png"
    alt="Sashite" /></a>
</p>
