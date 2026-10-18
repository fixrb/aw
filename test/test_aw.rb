# frozen_string_literal: true

require_relative File.join("support", "coverage")
require_relative File.join("..", "lib", "aw")
require "timeout"
require "fcntl"

raise unless Aw.supported?

# fork! returns what the block returns.
raise unless Aw.fork! { 6 * 7 } == 42
raise unless Aw.fork! { "bar" } == "bar"
raise unless Aw.fork! { [1, { a: :b }, 2.5, nil, true] } == [1, { a: :b }, 2.5, nil, true]
raise unless Aw.fork! { nil }.nil?

# Side effects stay in the child: objects, globals, constants, directory, ENV.
list = ["foo"]
raise unless Aw.fork! { list << "bar" } == %w[foo bar]
raise unless list == ["foo"]
$aw_test_global = 1
Aw.fork! { $aw_test_global = 2 }
raise unless $aw_test_global == 1
Aw.fork! { Object.const_set(:AwTestLeak, 1) }
raise if Object.const_defined?(:AwTestLeak)
directory = Dir.pwd
Aw.fork! { Dir.chdir("/") }
raise unless Dir.pwd == directory
Aw.fork! { ENV["AW_TEST"] = "1" }
raise if ENV.key?("AW_TEST")

# What the block raises is re-raised in the parent, with its message, its
# backtrace and its cause; an exception merely returned is returned.
begin
  Aw.fork! { raise ArgumentError, "boom" }
  raise "expected ArgumentError"
rescue ArgumentError => e
  raise unless e.message == "boom"
  raise unless e.backtrace.first.start_with?(__FILE__)
end
begin
  Aw.fork! do
    raise "inner"
  rescue RuntimeError
    raise "outer"
  end
  raise "expected RuntimeError"
rescue RuntimeError => e
  raise unless e.message == "outer" && e.cause.message == "inner"
end
raise unless Aw.fork! { RuntimeError.new("returned") }.message == "returned"
begin
  raise "handled by the parent"
rescue RuntimeError
  begin
    Aw.fork! { raise "without cause", cause: nil }
    raise "expected RuntimeError"
  rescue RuntimeError => e
    raise unless e.message == "without cause" && e.cause.nil?
  end
end

begin
  Aw.fork! { exit 3 }
  raise "expected SystemExit"
rescue SystemExit => e
  raise unless e.status == 3
end

begin
  Aw.fork! { raise Interrupt }
  raise "expected Interrupt"
rescue Interrupt
  nil
end

# A crash of the child is a ChildError carrying the status, which its
# message ends with; a ChildError is a StandardError.
raise unless Aw::ChildError < StandardError
begin
  Aw.fork! { Process.kill(:KILL, Process.pid) }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.status.signaled? && e.status.termsig == 9
  raise unless e.message.include?("did not deliver a result") && e.message.end_with?("(#{e.status})")
end

begin
  Aw.fork! { exit! 7 }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.status.exitstatus == 7
end

# A value that cannot be marshaled is a ChildError, not a silent nil.
begin
  Aw.fork! { -> {} }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("returned an instance of Proc")
end

begin
  Aw.fork! { $stdout }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("returned an instance of IO")
end

# An exception that cannot be marshaled is a ChildError that names it.
begin
  Aw.fork! { raise(RuntimeError.new("opaque").tap { |err| err.instance_variable_set(:@proc, -> {}) }) }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("raised RuntimeError (opaque)")
end

# A description that cannot be built still tells what the block did. The
# hooks raise NotImplementedError, which is not a StandardError: Aw rescues
# every exception there.
nameless = Class.new { def self.name = raise(NotImplementedError, "no name") }
begin
  Aw.fork! { nameless.new }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("the block returned something that cannot be transferred")
end
silent = Class.new(RuntimeError) { def message = raise(NotImplementedError, "no message") }
begin
  Aw.fork! { raise silent }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("the block raised something that cannot be transferred")
end

# What the parent raises while loading the result is a ChildError, not an
# exception of the block, even when it is not a StandardError.
class AwTestLoadedInChild
  def marshal_dump = Process.pid
  def marshal_load(pid) = (raise NotImplementedError, "dumped by #{pid}" unless pid == Process.pid)
end
loaded_in_child = AwTestLoadedInChild
begin
  Aw.fork! { loaded_in_child.new }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("undecodable") && e.message.include?("dumped by")
end

# A class the parent does not know cannot be loaded, and the reason is told.
begin
  Aw.fork! { Object.const_set(:AwTestChildOnly, Class.new); AwTestChildOnly.new } # rubocop:disable Style/Semicolon
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("undecodable") && e.message.include?("AwTestChildOnly")
end

# The block runs with the usual interrupt handling: a Timeout inside the
# block fires, and so does a signal.
begin
  Aw.fork! { Timeout.timeout(0.1) { sleep 5 } }
  raise "expected Timeout::Error"
rescue Timeout::Error
  nil
end
begin
  Aw.fork! { Process.kill(:TERM, Process.pid); sleep 5 } # rubocop:disable Style/Semicolon
  raise "expected SignalException"
rescue SignalException
  nil
end

# An anonymous class cannot be transferred either, and is named as such.
begin
  Aw.fork! { Class.new.new }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("returned an instance of an anonymous class")
end

# A child that leaves on its own, with exit!, delivered nothing.
begin
  Aw.fork! { exit! 0 }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("did not deliver a result")
end

# A child that closed its standard output still delivers its result.
raise unless Aw.fork! { $stdout.close; 1 } == 1 # rubocop:disable Style/Semicolon

# A grandchild holding the pipe does not delay the result.
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
raise unless Aw.fork! { Process.fork { sleep 5 }; 1 } == 1 # rubocop:disable Style/Semicolon
raise unless Process.clock_gettime(Process::CLOCK_MONOTONIC) - elapsed < 4

# A large result comes back whole.
raise unless Aw.fork! { "x" * 5_000_000 }.bytesize == 5_000_000

# The message is binary, whatever the default encodings. A child sets the
# internal one, as Rails does, quietly since Ruby warns about it.
raise unless Aw.fork! do
  $VERBOSE = nil
  Encoding.default_internal = Encoding::UTF_8
  Aw.fork! { [200, "é" * 100] } == [200, "é" * 100] && Aw.fork! { RuntimeError.new("ü") }.message == "ü"
end

# The parent's at_exit handlers do not run in the child, whatever the block
# does to leave: return, raise, break, exit, a redefined exit!, or a throw
# from the flush of a stream it replaced, with a matching catch in the
# parent; after a return, that throw does not cost the result.
witness_read, witness_write = IO.pipe
at_exit { witness_write.write("at_exit ran in #{Process.pid}\n") unless witness_write.closed? }
Aw.fork! { nil }
Aw.fork? { raise "boom" }
Aw.fork? { exit 1 }
Aw.fork! do
  Process.singleton_class.prepend(Module.new { def exit!(*) = nil })
  nil
end
begin
  [1].each { Aw.fork! { break } }
rescue Aw::ChildError
  nil
end
[1].each do
  Aw.fork! do
    Process.singleton_class.prepend(Module.new { def exit!(*) = nil })
    break
  end
rescue Aw::ChildError => e
  raise unless e.status.exitstatus == 70
end
throwing = Object.new
def throwing.write(*) = nil
def throwing.flush = throw(:aw_test_tag)
raise unless catch(:aw_test_tag) { Aw.fork! { $stdout = throwing; 1 } } == 1 # rubocop:disable Style/Semicolon
[1].each do
  catch(:aw_test_tag) { Aw.fork! { $stdout = throwing; break } } # rubocop:disable Style/Semicolon
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.status.exitstatus == 70
end
witness_write.close
raise "at_exit ran in a child" unless witness_read.read.empty?
witness_read.close

# The child's buffered output reaches the terminal, even with exit!.
read, write = IO.pipe
Aw.fork! do
  $stdout.reopen(write)
  $stdout.sync = false
  $stdout.print("from child")
end
write.close
raise unless read.read == "from child"
read.close
read, write = IO.pipe
[1].each do
  Aw.fork! do
    $stdout.reopen(write)
    $stdout.sync = false
    $stdout.print("before break")
    break
  end
rescue Aw::ChildError
  nil
end
write.close
raise unless read.read == "before break"
read.close
read, write = IO.pipe
Aw.fork! do
  $stderr.reopen(write)
  $stderr.sync = false
  $stderr.print("to stderr")
end
write.close
raise unless read.read == "to stderr"
read.close

# A parent interrupted at any moment leaves no child behind.
interrupted = 0
main = Thread.current
200.times do
  timer = Thread.new { sleep(rand * 0.004); main.raise(Interrupt) } # rubocop:disable Style/Semicolon
  begin
    Aw.fork! { sleep 0.01 }
  rescue Interrupt
    interrupted += 1
  end
  # A timer that has not fired yet fires during the masked join, and its
  # interruption is delivered when the mask is lifted: catch it there.
  begin
    Thread.handle_interrupt(Interrupt => :never) { timer.join }
  rescue Interrupt
    interrupted += 1
  end
end
raise "no interruption happened" if interrupted.zero?
begin
  raise "a child was left behind" if Process.wait(-1, Process::WNOHANG)
  raise "a child is still alive"
rescue Errno::ECHILD
  nil
end

# A parent that gives up waiting kills and reaps the child: no zombie.
pid_holder = IO.pipe
begin
  Timeout.timeout(0.5) do
    Aw.fork! do
      pid_holder[1].write(Process.pid.to_s)
      pid_holder[1].close
      sleep 60
    end
  end
  raise "expected Timeout::Error"
rescue Timeout::Error
  pid_holder[1].close
  child_pid = pid_holder[0].read.to_i
  pid_holder[0].close
  raise "the child did not tell its pid" if child_pid.zero?
  begin
    Process.kill(0, child_pid)
    raise "child #{child_pid} is still alive"
  rescue Errno::ESRCH
    nil
  end
end

# A block that breaks, returns or throws delivers nothing, and is told so.
[1].each do
  Aw.fork! { break }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("left without returning or raising") && e.status.exitstatus == 70
end
begin
  catch(:out) { Aw.fork! { throw :out } }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.status.exitstatus == 70
end

# A standard output that cannot be flushed does not lose the result; a
# Marshal hook that raises is reported with its message.
sink = Object.new
def sink.write(*) = nil
def sink.flush = raise(NotImplementedError)
raise unless Aw.fork! { $stdout = sink; 1 } == 1 # rubocop:disable Style/Semicolon
class AwTestRaisingDump
  def marshal_dump = raise(NotImplementedError, "no dump")
end
raising_dump = AwTestRaisingDump
begin
  Aw.fork! { raising_dump.new }
  raise "expected ChildError"
rescue Aw::ChildError => e
  raise unless e.message.include?("no dump")
end

# fork? reports the child only: an exception of the parent propagates.
begin
  Timeout.timeout(0.5) { Aw.fork? { sleep 60 } }
  raise "expected Timeout::Error"
rescue Timeout::Error
  nil
end

# The protocol is checked, whatever a block that reaches the pipe writes:
# a forged message is only accepted when it is complete, well formed, and
# followed by a normal exit of the child.
pipe_writer = lambda do
  ObjectSpace.each_object(IO).select do |io|
    !io.closed? && io.fileno > 2 && io.stat.pipe? && (io.fcntl(Fcntl::F_GETFL) & Fcntl::O_ACCMODE) == Fcntl::O_WRONLY
  end.max_by(&:fileno)
end
forged = lambda do |bytes, exit_status|
  Aw.fork! do
    pipe_writer.call.write(bytes)
    exit!(exit_status)
  end
end
frame = ->(bytes) { "#{[bytes.bytesize].pack("Q>")}#{bytes}" }
message = Marshal.dump([:return, 42])
AwTestPair = Struct.new(:kind, :value)
raise unless forged.call(frame.call(message), 0) == 42
[
  [frame.call(message), 3, "did not deliver"],
  [frame.call(message)[0, 3], 0, "did not deliver"],
  ["#{[100].pack("Q>")}#{message}", 0, "did not deliver"],
  [frame.call("garbage!"), 0, "undecodable"],
  [frame.call(Marshal.dump([:bogus, nil])), 0, "unexpected"],
  [frame.call(Marshal.dump([:raise, 42])), 0, "unexpected"],
  [frame.call(Marshal.dump([:opaque, 42])), 0, "unexpected"],
  [frame.call(Marshal.dump([:return, 1, 2])), 0, "unexpected"],
  [frame.call(Marshal.dump(AwTestPair.new(:return, 42))), 0, "unexpected"],
  [frame.call(Marshal.dump([:opaque, "é".encode(Encoding::UTF_16LE)])), 0, "unexpected"],
  [frame.call("\x04\b#{"[\x06" * 1_000_000}0".b), 0, "undecodable"],
  ["#{[2**62].pack("Q>")}x", 0, "did not deliver"]
].each do |bytes, exit_status, expected|
  forged.call(bytes, exit_status)
  raise "expected ChildError for #{expected}"
rescue Aw::ChildError => e
  raise "#{expected}: #{e.message}" unless e.message.include?(expected)
end
# fork? answers true only for a block that returned, never for a forged value.
[[:return, 42], [:raise, RuntimeError.new("forged")]].each do |forgery|
  answer = Aw.fork? do
    pipe_writer.call.write(frame.call(Marshal.dump(forgery)))
    exit!(0)
  end
  raise "fork? believed #{forgery}" unless false.equal?(answer)
end
# A load that runs out of memory is a ChildError too; an interruption during
# the load propagates.
failure = nil
Marshal.singleton_class.alias_method(:aw_test_load, :load)
Marshal.define_singleton_method(:load) { |*| raise failure }
begin
  failure = NoMemoryError.new("failed to allocate memory")
  begin
    Aw.fork! { 1 }
    raise "expected ChildError"
  rescue Aw::ChildError => e
    raise unless e.message.include?("undecodable message (failed to allocate memory)")
  end
  failure = Interrupt.new
  begin
    Aw.fork! { 1 }
    raise "expected Interrupt"
  rescue Interrupt
    nil
  end
ensure
  Marshal.singleton_class.send(:remove_method, :load)
  Marshal.singleton_class.alias_method(:load, :aw_test_load)
end

# A child that ignores SIGTERM is still killed when the parent gives up.
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  Timeout.timeout(0.5) { Aw.fork! { trap(:TERM) { nil }; sleep 60 } } # rubocop:disable Style/Semicolon
  raise "expected Timeout::Error"
rescue Timeout::Error
  nil
end
raise "the child was not killed" unless Process.clock_gettime(Process::CLOCK_MONOTONIC) - elapsed < 2

# An interruption landing right after the fork, before the parent has even
# recorded the child's pid, still leads to the child being reaped. The
# stubbed fork interrupts its own thread in that window: an exception, or a
# Thread#kill from another thread, which is not an exception.
interruption = nil
Process.singleton_class.alias_method(:aw_test_fork, :fork)
Process.define_singleton_method(:fork) do |&block|
  pid = aw_test_fork(&block)
  interruption.call(Thread.current)
  sleep 0.001 # a blocking call in the window: forked, not yet recorded
  pid
end
begin
  [Interrupt, IOError].each do |klass|
    interruption = ->(thread) { thread.raise(klass) }
    Aw.fork! { sleep 60 }
    raise "expected #{klass}"
  rescue klass
    nil
  end
  interruption = ->(thread) { Thread.new { thread.kill }.join }
  Thread.new { Aw.fork! { sleep 60 } }.join
ensure
  Process.singleton_class.send(:remove_method, :fork)
  Process.singleton_class.alias_method(:fork, :aw_test_fork)
end
begin
  raise "a child was left behind after the fork window" if Process.wait(-1, Process::WNOHANG)
  raise "a child is still alive after the fork window"
rescue Errno::ECHILD
  nil
end

# Reaping a child that was already reaped, or that has exited and waits to
# be reaped, never sends a signal: the pid may belong to another process.
reaped = Process.fork { exit! 0 }
Process.wait(reaped)
exit_read, exit_write = IO.pipe
exited = Process.fork { exit! 0 }
exit_write.close
exit_read.read # end of file: the child has closed its descriptors, and exits
exit_read.close
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
until `ps -o stat= -p #{exited}`.start_with?("Z") || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  sleep 0.01
end
killed = []
Process.singleton_class.alias_method(:aw_test_kill, :kill)
Process.define_singleton_method(:kill) { |*args| killed << args }
begin
  Aw::Fork.send(:reap, reaped)
  Aw::Fork.send(:reap, exited)
ensure
  Process.singleton_class.send(:remove_method, :kill)
  Process.singleton_class.alias_method(:kill, :aw_test_kill)
end
raise "kill was sent to a child that had exited" unless killed.empty?
begin
  Process.wait(exited)
  raise "the child that had exited was not reaped"
rescue Errno::ECHILD
  nil
end

# A child reaped by someone else between the check and the kill is no error.
running = Process.fork { sleep 60 }
Process.define_singleton_method(:kill) do |signal, pid|
  aw_test_kill(signal, pid)
  Process.wait(pid)
  raise Errno::ESRCH
end
begin
  Aw::Fork.send(:reap, running)
ensure
  Process.singleton_class.send(:remove_method, :kill)
  Process.singleton_class.alias_method(:kill, :aw_test_kill)
end

# A child is waited for once: its pid is never touched again once reaped.
waits = []
Process.singleton_class.alias_method(:aw_test_wait2, :wait2)
Process.define_singleton_method(:wait2) { |*args| waits << args; aw_test_wait2(*args) } # rubocop:disable Style/Semicolon
begin
  Aw.fork! { 1 }
ensure
  Process.singleton_class.send(:remove_method, :wait2)
  Process.singleton_class.alias_method(:wait2, :aw_test_wait2)
end
raise "wait2 was called #{waits.size} times" unless waits.size == 1

# The child holds no read end of a pipe: orphaned, it gets EPIPE instead of
# blocking on a pipe nobody reads.
readers = Aw.fork! do
  ObjectSpace.each_object(IO).count do |io|
    !io.closed? && io.fileno > 2 && io.stat.pipe? && (io.fcntl(Fcntl::F_GETFL) & Fcntl::O_ACCMODE) == Fcntl::O_RDONLY
  end
end
raise "the child holds #{readers} read end(s) of a pipe" unless readers.zero?

# No file descriptor leaks across calls.
before = Dir.children("/dev/fd").size
20.times { Aw.fork! { 1 } }
raise unless Dir.children("/dev/fd").size == before

# Nested forks work.
raise unless Aw.fork! { Aw.fork! { Aw.fork! { 3 } + 1 } + 1 } == 5

# A fiber scheduler the parent set does not see the block: in the child, a
# sleep or an IO of the block is blocking, instead of transferring to the
# parent's other fibers, copied by the fork. The parent's side goes through
# the scheduler as usual.
parent_pid = Process.pid
scheduler = Object.new
scheduler.define_singleton_method(:fiber) { |&block| Fiber.new(blocking: false, &block).tap(&:resume) }
seen = -> { raise "the scheduler saw the block" unless Process.pid == parent_pid }
scheduler.define_singleton_method(:kernel_sleep) { |*| seen.call }
scheduler.define_singleton_method(:block) { |*| seen.call }
scheduler.define_singleton_method(:unblock) { |*| nil }
scheduler.define_singleton_method(:io_wait) do |io, events, _timeout|
  seen.call
  IO.select(events.anybits?(IO::READABLE) ? [io] : nil, events.anybits?(IO::WRITABLE) ? [io] : nil)
  events
end
scheduler.define_singleton_method(:close) { nil }
scheduled = nil
Fiber.set_scheduler(scheduler)
begin
  Fiber.schedule { scheduled = Aw.fork! { sleep 0.001; :slept } } # rubocop:disable Style/Semicolon
ensure
  Fiber.set_scheduler(nil)
end
raise "got #{scheduled.inspect}" unless scheduled == :slept

# fork? tells whether the block returned, whatever it returned.
raise unless true.equal?(Aw.fork? { 6 * 7 })
raise unless true.equal?(Aw.fork? { -> {} })
raise unless true.equal?(Aw.fork? { nil })
raise unless false.equal?(Aw.fork? { raise "boom" })
raise unless false.equal?(Aw.fork? { raise(ScriptError.new("x").tap { |e| e.instance_variable_set(:@io, $stdout) }) })
raise unless false.equal?(Aw.fork? { exit 1 })
raise unless false.equal?(Aw.fork? { exit 0 })
raise unless false.equal?(Aw.fork? { raise Interrupt })
list = ["foo"]
raise unless true.equal?(Aw.fork? { list << "bar" })
raise unless list == ["foo"]

begin
  Aw.fork? { Process.kill(:KILL, Process.pid) }
  raise "expected ChildError"
rescue Aw::ChildError
  nil
end

# A Ruby without fork(2) is refused, before any pipe is opened.
descriptors = Dir.children("/dev/fd").size
Aw.singleton_class.alias_method(:aw_test_supported?, :supported?)
Aw.define_singleton_method(:supported?) { false }
begin
  %i[fork! fork?].each do |name|
    Aw.public_send(name) { 1 }
    raise "expected NotImplementedError for #{name}"
  rescue NotImplementedError => e
    raise unless e.message == "fork(2) is not available on this Ruby"
  end
ensure
  Aw.singleton_class.send(:remove_method, :supported?)
  Aw.singleton_class.alias_method(:supported?, :aw_test_supported?)
end
raise unless Dir.children("/dev/fd").size == descriptors

# The fork is private: its helpers and constants are not reachable.
raise if Aw::Fork.respond_to?(:reap)
begin
  raise "Aw::Fork::EXIT is public" if Aw::Fork::EXIT
rescue NameError
  nil
end

# A block is required.
%i[fork! fork?].each do |name|
  Aw.public_send(name)
  raise "expected ArgumentError for #{name}"
rescue ArgumentError => e
  raise unless e.message == "a block must be provided"
end
