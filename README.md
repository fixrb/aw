# Aw

[![Build Status](https://api.travis-ci.org/fixrb/aw.svg?branch=master)][travis]
[![Code Climate](https://codeclimate.com/github/fixrb/aw/badges/gpa.svg)][codeclimate]
[![Gem Version](https://badge.fury.io/rb/aw.svg)][gem]
[![Inline docs](https://inch-ci.org/github/fixrb/aw.svg?branch=master)][inchpages]
[![Documentation](https://img.shields.io/:yard-docs-38c800.svg)][rubydoc]

> Aw, fork! 😬

Creates a subprocess to execute a block inside.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "aw"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aw

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

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

***

<p>
  This project is sponsored by:<br />
  <a href="https://sashite.com/"><img
    src="https://github.com/fixrb/aw/raw/master/img/sashite.png"
    alt="Sashite" /></a>
</p>

[gem]: https://rubygems.org/gems/aw
[travis]: https://travis-ci.org/fixrb/aw
[codeclimate]: https://codeclimate.com/github/fixrb/aw
[inchpages]: https://inch-ci.org/github/fixrb/aw
[rubydoc]: https://rubydoc.info/gems/aw
