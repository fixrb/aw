# Aw

[![Version](https://img.shields.io/github/v/tag/fixrb/aw?label=Version&logo=github)](https://github.com/fixrb/aw/tags)
[![Yard documentation](https://img.shields.io/badge/Yard-documentation-blue.svg?logo=github)](https://rubydoc.info/github/fixrb/aw/main)
[![Ruby](https://github.com/fixrb/aw/workflows/Ruby/badge.svg?branch=main)](https://github.com/fixrb/aw/actions?query=workflow%3Aruby+branch%3Amain)
[![RuboCop](https://github.com/fixrb/aw/workflows/RuboCop/badge.svg?branch=main)](https://github.com/fixrb/aw/actions?query=workflow%3Arubocop+branch%3Amain)
[![License](https://img.shields.io/github/license/fixrb/aw?label=License&logo=github)](https://github.com/fixrb/aw/raw/main/LICENSE.md)

> Aw, fork 😬

![Aw](https://github.com/fixrb/aw/raw/main/img/aw.jpg)

Creates a sub-process to execute a block inside, and returns what it returns (or a boolean).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "aw"
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install aw
```

## Usage

To make __Aw__ available:

```ruby
require "aw"
```

There are two methods:

- `fork!`
- `fork?`

### Method `.fork!`

Executes a block of code in a sub-process, and returns the result:

```ruby
Aw.fork! { 6 * 7 } # => 42
```

When the execution of a block of code causes side effects, these are limited to the sub-process:

```ruby
arr = ["foo"] # => ["foo"]

Aw.fork! { arr << "FUU" } # => ["foo", "FUU"]

arr # => ["foo"]
```

Exceptions raised in a block of code are propagated:

```ruby
Aw.fork! { nil + 1 }
```

results in the error:

> `NoMethodError` (undefined method `+' for nil:NilClass)

### Method `.fork?`

Executes a block of code in a sub-process, and returns `true` if no exception is thrown:

```ruby
Aw.fork? { 6 * 7 } # => true
```

When the execution of a block of code causes side effects, these are limited to the sub-process:

```ruby
arr = ["foo"] # => ["foo"]

Aw.fork? { arr << "FUU" } # => true

arr # => ["foo"]
```

When an exception is raised in a code block, `false` is returned:

```ruby
Aw.fork? { nil + 1 } # => false
```

## Contact

* Source code: https://github.com/fixrb/aw

## Versioning

__Aw__ follows [Semantic Versioning 2.0](https://semver.org/).

## License

The [gem](https://rubygems.org/gems/aw) is available as open source under the terms of the [MIT License](https://github.com/fixrb/aw/raw/main/LICENSE.md).

***

<p>
  This project is sponsored by:<br />
  <a href="https://sashite.com/"><img
    src="https://github.com/fixrb/aw/raw/main/img/sashite.png"
    alt="Sashité" /></a>
</p>
