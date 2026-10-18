# Aw

[![Version](https://img.shields.io/github/v/tag/fixrb/aw?label=Version&logo=github)](https://github.com/fixrb/aw/tags)
[![Yard documentation](https://img.shields.io/badge/Yard-documentation-blue.svg?logo=github)](https://rubydoc.info/github/fixrb/aw/main)
[![License](https://img.shields.io/github/license/fixrb/aw?label=License&logo=github)](https://github.com/fixrb/aw/raw/main/LICENSE.md)

> Aw, fork 😬

![Aw](https://github.com/fixrb/aw/raw/main/img/aw.jpg)

Runs a block in a forked child process and brings back what it returned, or re-raises what it raised. What the block does to the process stays in the child; what it does outside, to files or to other processes, does not.

## Installation

```ruby
# Gemfile
gem "aw"
```

Aw requires Ruby 3.3 or later and `fork(2)`: it runs on Linux, macOS and the BSDs with CRuby, and declines elsewhere (Windows, JRuby) with a `NotImplementedError`. `Aw.supported?` tells beforehand.

## Usage

```ruby
require "aw"

Aw.fork! { 6 * 7 } # => 42
```

Side effects of the block on the process stay in the child: mutations, globals, constants, the current directory, `ENV`, a crash.

```ruby
list = ["foo"]
Aw.fork! { list << "bar" } # => ["foo", "bar"]
list                       # => ["foo"]
```

What the block raises is re-raised in the parent, with its message, backtrace and cause, including `SystemExit` from an `exit`:

```ruby
Aw.fork! { raise ArgumentError, "boom" } # raises ArgumentError: boom
```

Left uncaught, it ends the parent as it would have ended the child: an `exit 0`, or a `SignalException` the block raised (`KILL` included), terminates the parent with that status or that signal.

`fork?` only tells whether the block returned:

```ruby
Aw.fork? { 6 * 7 }          # => true
Aw.fork? { raise "boom" }   # => false
Aw.fork? { exit 0 }         # => false
```

It reports the child only: an exception raised in the parent while waiting, such as an `Interrupt` or a `Timeout::Error`, propagates.

## What comes back, and what cannot

The result travels through a pipe with `Marshal`, so it must be a marshalable value: numbers, strings, symbols, arrays, hashes, and instances of named classes whose state is marshalable. A `Proc`, an `IO`, an instance of an anonymous class, or an exception carrying such a thing (a `KeyError` raised by a hash that holds a `Proc` carries that hash) cannot come back; `fork!` then raises `Aw::ChildError`, which says what the block returned or raised and why Marshal refused it. Neither can an instance of a class the parent does not know: a class defined or required inside the block exists in the child only, and the parent cannot load it (`Aw::ChildError: … undefined class/module Foo`). A constant the parent registered for autoload is the exception: `Marshal` autoloads it, and so runs that file, in the parent. What the parent raises while loading the result, short of an interruption, is an `Aw::ChildError` too, never mistaken for an exception of the block: a `marshal_load` of one of its classes, a failed autoload, a structure too deep or too large for the parent. `fork?` transfers neither the value nor the exception, and is not concerned.

`Aw::ChildError` is also raised when the child died without delivering a result: killed by a signal that Ruby does not turn into an exception (`KILL`, `SEGV`), left on its own with `exit!` or `exec`, or left the block with a `break`, a `return` or a `throw`. Its `status` is the child's `Process::Status`, and tells the cases apart: `signaled?` for a crash, `exitstatus` 70 (`EX_SOFTWARE`) for a block that left without returning or raising, 0 for a result that cannot be transferred or loaded, and the block's own code for an `exit!` or an `exec`: a block calling `exit! 70` is reported as one that left without returning, and `exit! 0` as a child that did not deliver a result.

```ruby
Aw.fork! { -> {} }
# raises Aw::ChildError: the block returned an instance of Proc, which cannot be transferred from the child: …

Aw.fork! { Process.kill(:KILL, Process.pid) }
# raises Aw::ChildError: the child did not deliver a result (pid 42 SIGKILL (signal 9))
```

The value that comes back is a copy: an object returns as a new object, and its frozen state does not travel (a frozen string or array returns unfrozen, while a `Range` or a `Data` returns frozen, as `Marshal` makes them). An exception comes back with its message, its backtrace as strings (which starts in the child and ends in the parent, since the stack was copied; `backtrace_locations` is `nil`) and the cause it had in the child, never the exception the parent may be handling.

## Guarantees

- The child leaves with `exit!` after flushing its standard output and error, whatever the block does to leave (returning, raising, `exit`, `break`, `return`, `throw`, a redefined `exit!`, a replaced stream whose `flush` throws): the parent's `at_exit` handlers run once, in the parent. An `at_exit` registered by the block itself never runs.
- The child's standard output and error go where the parent's go. Any other buffered `IO` opened by the parent and written by the block, `STDOUT` included when the block replaced `$stdout`, is not flushed, and that output is lost: flush it in the block, and in the parent before the call, or what the parent had buffered is written twice.
- The block runs with the usual interrupt handling, whatever mask the caller set with `Thread.handle_interrupt`: a `Timeout` inside the block, a `Thread#raise` or a signal reach it. A signal that Ruby turns into an exception (`INT`, `TERM`, `HUP`) is then re-raised in the parent, like any exception of the block.
- The message is length-prefixed and binary, whatever the default encodings: a process the block spawned and left running does not delay the result, as long as it does not write to the pipe. When the child delivers no result, though, the parent waits for the end of the pipe, so a process the block forked without `exec` and left running delays the `Aw::ChildError` until it exits (`spawn` and `system` do not hold the pipe).
- Aw has no timeout of its own: `fork!` and `fork?` wait until the child exits, whatever keeps it alive (a block that loops or sleeps, a child stopped by `SIGSTOP`, a standard stream whose `flush` blocks, a thread that goes on after the result was written). Wrap code you do not trust in a `Timeout` of your own.
- If the parent is interrupted while waiting (`Interrupt`, `Timeout`, `Thread#kill`), the child is killed and reaped before the interruption proceeds, with no window between the fork and that guard. A second interruption during the reaping itself can still leave a zombie.
- No file descriptor is left open after a call.
- Forks can be nested. When an outer fork is killed by an interrupted parent, its own children are orphaned, since `SIGKILL` leaves no time to reap them.
- A fork costs a few milliseconds; the pages of the parent are shared copy-on-write, and the cost grows with the size of the parent (about 2 ms at 50 MB, 20 ms at 700 MB).

## Things to know about fork

- Only the thread that calls `fork!` exists in the child; other threads of the parent are not copied. A block that relies on a background thread of the parent will not find it.
- The child is blocking, whatever fiber `fork!` was called from: a fiber scheduler the parent set (`async`, say) does not see the block, whose sleeps and IO would otherwise hand the child over to the parent's other fibers, copied by the fork. The parent's side, reading the result and waiting for the child, goes through the scheduler as usual. A `Fiber.yield` in the block raises a `FiberError`, since the fork makes the current fiber the root one.
- On macOS, the child of a process that loaded Objective-C frameworks from several threads may crash when it first uses an Objective-C class; `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` in the environment the parent is started with is Apple's switch for that.
- Aw reaps its own child: a parent that reaps children on its own, with `trap(:CHLD) { Process.wait(-1, Process::WNOHANG) }` or `trap(:CHLD, "IGNORE")`, can take the child's status first, and the call then raises `Errno::ECHILD`.
- The file descriptors of the parent are shared with the child, offsets included: a block that writes to a file, a socket or a database connection the parent opened changes it for the parent too. Open such connections in the block.
- `$stdout` replaced by a `StringIO` in the parent is not shared with the child; capture output inside the block and return it.
- SimpleCov stores the coverage of a process from an `at_exit` handler, which `exit!` skips: the code the child runs is not in the parent's report. With `merge_subprocesses true` (`enable_for_subprocesses true` before SimpleCov 1.3), call `SimpleCov.result` in an `ensure` of the block to store the child's share; the parent merges it.
- The parent deserializes, with `Marshal`, what the child wrote; the child ran your block, which could reach the pipe and write anything. Aw isolates the side effects of code you trust; it is not a sandbox for code you do not. A hostile block can make `fork!` return or raise anything, make `fork?` answer `true`, choose the message of an `Aw::ChildError`, make the parent hold as much memory as it writes, run the parent's `marshal_load` methods and autoloads, and, from a continuation the parent captured (`callcc`), run the parent's code in the child: only the `status` of an `Aw::ChildError` comes from the system. Running as the parent's user, it can also signal the parent and leave processes behind; Aw kills and reaps the child only.

## Changes in 1.0

- An exception *returned* by the block is returned, not raised; only what the block raises is re-raised.
- A child that died, or a result that cannot be marshaled or loaded, is an `Aw::ChildError` with the child's status and the reason, instead of an `ArgumentError` (`marshal data too short`, `undefined class/module`), or a `nil` from `fork?`.
- `fork?` answers whether the block returned: `exit 0` in the block is now `false`, and `exit!`, a `break`, a `return` or a `throw` an `Aw::ChildError` (0.2.1 answered `true` or `false`).
- The child always leaves with `exit!`, after flushing its standard streams (0.2.1 lost what `fork!` had buffered): `fork?`, and `fork!` on a result it could not dump, no longer run the parent's `at_exit` handlers or print a backtrace in the child, and an `at_exit` registered by the block never runs.
- A process the block left running no longer delays the result.
- The pipe is closed on every path; the parent kills and reaps the child when interrupted (0.2.1 left it running).
- `Aw.supported?`; `NotImplementedError` raised before any pipe is opened (0.2.1 leaked one); `ArgumentError` without a block (0.2.1 raised a `LocalJumpError` from `fork!`, and `fork?` forked a child that went on running the caller's code).
- `require "aw"` no longer loads `English` (`$CHILD_STATUS` and the other aliases); `Aw::Fork`, private, is now a module.
- Ruby 3.3 or later.

## Versioning

Aw follows [Semantic Versioning 2.0](https://semver.org/).

## License

The [gem](https://rubygems.org/gems/aw) is available as open source under the terms of the [MIT License](https://github.com/fixrb/aw/raw/main/LICENSE.md).

## Sponsors

This project is sponsored by [Sashité](https://sashite.com/)
