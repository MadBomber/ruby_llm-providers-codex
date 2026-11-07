# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'ruby_llm/providers/codex'
require 'minitest/autorun'
require 'json'

# Stands in for Runner: replays canned stdout lines and records each call.
class FakeRunner
  Status = Struct.new(:exitstatus) do
    def success?
      exitstatus.zero?
    end
  end

  attr_reader :calls

  def initialize(*outputs, exitstatus: 0, stderr: '')
    @outputs = outputs
    @exitstatus = exitstatus
    @stderr = stderr
    @calls = []
  end

  def run(argv, stdin: '', cwd: nil, timeout: nil, env: {})
    @calls << { argv: argv, stdin: stdin, cwd: cwd, timeout: timeout, env: env }
    lines = @outputs.shift || []
    lines.each { |line| yield line if block_given? }
    RubyLLM::Providers::Codex::Runner::Result.new(stdout: lines.join, stderr: @stderr,
                                                  status: Status.new(@exitstatus))
  end
end

# JSON lines shaped like `codex exec --json` output.
module CodexOutput
  module_function

  def line(hash)
    "#{JSON.generate(hash)}\n"
  end

  def thread_started(id = 'thread-1')
    line('type' => 'thread.started', 'thread_id' => id)
  end

  def agent_message(text, id: 'item-1')
    line('type' => 'item.completed', 'item' => { 'id' => id, 'type' => 'agent_message', 'text' => text })
  end

  def other_item(type = 'reasoning')
    line('type' => 'item.completed', 'item' => { 'id' => 'r1', 'type' => type, 'text' => 'thinking...' })
  end

  def turn_completed(input: 120, cached: 100, output: 9, reasoning: 4, cache_write: 0)
    line('type' => 'turn.completed', 'usage' => {
           'input_tokens' => input, 'cached_input_tokens' => cached, 'cache_write_input_tokens' => cache_write,
           'output_tokens' => output, 'reasoning_output_tokens' => reasoning
         })
  end

  def turn_failed(message)
    line('type' => 'turn.failed', 'error' => { 'message' => message })
  end

  def error(message)
    line('type' => 'error', 'message' => message)
  end

  def reply(text, thread_id: 'thread-1')
    [thread_started(thread_id), line('type' => 'turn.started'), agent_message(text), turn_completed]
  end
end

def user_message(text, **)
  RubyLLM::Message.new(role: :user, content: text, **)
end

def assistant_message(text)
  RubyLLM::Message.new(role: :assistant, content: text)
end

def system_message(text)
  RubyLLM::Message.new(role: :system, content: text)
end
