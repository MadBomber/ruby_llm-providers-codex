# frozen_string_literal: true

require 'open3'

module RubyLLM
  module Providers
    class Codex < Provider
      # Spawns the CLI, feeds it stdin, and yields each stdout line on the
      # caller's thread as it arrives. The process group is killed when the
      # timeout passes.
      class Runner
        Result = Data.define(:stdout, :stderr, :status)
        GRACE_SECONDS = 2
        EOF = Object.new.freeze

        # @param argv [Array<String>] command and arguments
        # @param stdin [String] text written to the process's stdin
        # @param cwd [String, nil] working directory (default: Dir.pwd)
        # @param timeout [Numeric, nil] seconds before the process is killed
        # @param env [Hash] extra environment variables
        # @yield [String] each line of stdout
        # @return [Result]
        def run(argv, stdin: '', cwd: nil, timeout: nil, env: {})
          lines = []
          Open3.popen3(env.to_h, *argv, chdir: cwd || Dir.pwd, pgroup: true) do |input, output, error, wait|
            feeder = Thread.new { feed(input, stdin) }
            errors = Thread.new { error.read }
            queue  = Queue.new
            reader = Thread.new { pump(output, queue) }
            deadline = timeout && (now + timeout)
            drain(queue, deadline) do |line|
              lines << line
              yield line if block_given?
            end
            [feeder, reader].each(&:join)
            Result.new(stdout: lines.join, stderr: errors.value.to_s, status: wait.value)
          rescue TimeoutError
            terminate(wait)
            raise TimeoutError, "#{argv.first} did not finish within #{timeout}s"
          end
        rescue Errno::ENOENT => e
          raise Error, "cannot run #{argv.first.inspect}: #{e.message}"
        end

        private

        def feed(input, text)
          input.binmode
          input.write(text.to_s)
        rescue Errno::EPIPE, IOError
          nil
        ensure
          input.close unless input.closed?
        end

        def pump(output, queue)
          output.each_line { |line| queue << line }
        ensure
          queue << EOF
        end

        # Pops lines until EOF, raising TimeoutError once the deadline passes.
        def drain(queue, deadline)
          loop do
            remaining = deadline && [deadline - now, 0].max
            line = remaining ? queue.pop(timeout: remaining) : queue.pop
            raise TimeoutError if line.nil?
            break if line.equal?(EOF)

            yield line
          end
        end

        def terminate(wait)
          Process.kill('TERM', -wait.pid)
          return if wait.join(GRACE_SECONDS)

          Process.kill('KILL', -wait.pid)
          wait.join
        rescue Errno::ESRCH, Errno::ECHILD
          nil
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
