# frozen_string_literal: true

require 'test_helper'

class TestCodexResponse < Minitest::Test
  Response = RubyLLM::Providers::Codex::Response

  def response
    Response.new(model: 'gpt-5')
  end

  def test_reply_becomes_message
    r = response
    CodexOutput.reply('pong', thread_id: 't1').each { |line| r.ingest(line) }
    message = r.message

    assert_equal 'pong', message.content
    assert_equal 't1', r.session_id
    assert_equal 20, message.tokens.input
    assert_equal 100, message.tokens.cache_read
    assert_equal 9, message.tokens.output
    assert_equal 4, message.tokens.thinking
    assert_predicate message, :stopped?
    assert_equal 't1', message.raw['thread_id']
  end

  def test_streams_each_agent_message_and_keeps_the_last
    r = response
    chunks = []
    lines = [CodexOutput.thread_started, CodexOutput.other_item, CodexOutput.agent_message('working...'),
             "2026-11-07T03:01:12Z ERROR noise\n", CodexOutput.agent_message('done'), CodexOutput.turn_completed]
    lines.each { |line| r.ingest(line) { |chunk| chunks << chunk } }

    assert_equal ['working...', 'done'], chunks.map(&:content)
    assert(chunks.all?(RubyLLM::Chunk))
    assert_equal 'done', r.message.content
  end

  def test_failures_raise
    r = response
    [CodexOutput.thread_started, CodexOutput.turn_failed('token expired')].each { |line| r.ingest(line) }
    error = assert_raises(RubyLLM::Providers::Codex::Error) { r.message }

    assert_includes error.message, 'token expired'

    r = response
    r.ingest(CodexOutput.error('boom'))

    assert_raises(RubyLLM::Providers::Codex::Error) { r.message }
  end

  def test_missing_reply_raises_with_diagnostics
    run = RubyLLM::Providers::Codex::Runner::Result.new(stdout: '', stderr: 'bad', status: FakeRunner::Status.new(1))
    error = assert_raises(RubyLLM::Providers::Codex::Error) { response.message(run) }

    assert_includes error.message, '(1)'
    assert_includes error.message, 'bad'
  end
end
