# frozen_string_literal: true

require 'test_helper'

class TestCodexRunner < Minitest::Test
  Runner = RubyLLM::Providers::Codex::Runner

  def ruby(script)
    [RbConfig.ruby, '-e', script]
  end

  def test_feeds_stdin_and_yields_lines
    seen = []
    result = Runner.new.run(ruby('STDIN.read.each_line { |l| puts l.upcase }; $stderr.puts "err"'),
                            stdin: "a\nb\n") { |line| seen << line }
    assert_equal %W[A\n B\n], seen
    assert_equal "A\nB\n", result.stdout
    assert_equal "err\n", result.stderr
    assert_predicate result.status, :success?
  end

  def test_env_and_cwd
    dir = File.realpath(Dir.tmpdir)
    result = Runner.new.run(ruby('print ENV["RL_TEST"], " ", Dir.pwd'), env: { 'RL_TEST' => 'yes' }, cwd: dir)
    assert_equal "yes #{dir}", result.stdout
  end

  def test_timeout_kills_process
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(RubyLLM::Providers::Codex::TimeoutError) do
      Runner.new.run(ruby('$stdout.sync = true; puts "x"; sleep 30'), timeout: 0.3) { |_| nil }
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
  end

  def test_missing_command
    error = assert_raises(RubyLLM::Providers::Codex::Error) { Runner.new.run(['/no/such/claude-cli']) }
    assert_includes error.message, 'cannot run'
  end
end
