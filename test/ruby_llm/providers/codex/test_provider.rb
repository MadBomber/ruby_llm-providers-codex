# frozen_string_literal: true

require 'test_helper'

class TestCodexProvider < Minitest::Test
  Provider = RubyLLM::Providers::Codex

  def teardown
    Provider.runner = nil
  end

  def chat(model: 'default')
    RubyLLM.chat(model: model, provider: :codex)
  end

  def test_registration_and_class_facts
    assert_equal Provider, RubyLLM::Provider.resolve(:codex)
    assert_equal 'codex', Provider.slug
    assert_predicate Provider, :local?
    assert_predicate Provider, :assume_models_exist?
    refute_predicate Provider, :accepts_tools?
    assert_empty Provider.configuration_requirements
    assert_includes RubyLLM::Configuration.options, :codex_sandbox
    refute_nil Provider::VERSION
    assert_equal %w[default], Provider.new(RubyLLM.config).list_models.map(&:id)
  end

  def test_single_turn_through_rubyllm_chat
    Provider.runner = FakeRunner.new(CodexOutput.reply('pong'))
    reply = chat(model: 'gpt-5').with_instructions('Answer briefly.').ask('ping')

    assert_equal 'pong', reply.content
    call = Provider.runner.calls.first
    expected = ['codex', 'exec', '--json', '--skip-git-repo-check', '--model', 'gpt-5',
                '--config', 'developer_instructions="Answer briefly."', '-']

    assert_equal expected, call[:argv]
    assert_equal 'ping', call[:stdin]
  end

  def test_second_turn_resumes_the_thread
    Provider.runner = FakeRunner.new(CodexOutput.reply('one', thread_id: 't1'),
                                     CodexOutput.reply('two', thread_id: 't1'))
    c = chat
    c.ask('first')
    c.ask('second')
    second = Provider.runner.calls.last

    assert_equal %w[codex exec resume --json --skip-git-repo-check t1 -], second[:argv]
    assert_equal 'second', second[:stdin]
  end

  def test_rewound_history_replays_without_resume
    Provider.runner = FakeRunner.new(CodexOutput.reply('one'), CodexOutput.reply('two', thread_id: 't2'))
    c = chat
    c.ask('first')
    c.messages.pop
    c.ask('second')
    second = Provider.runner.calls.last

    refute_includes second[:argv], 'resume'
    assert_includes second[:stdin], '<user>'
  end

  def test_streaming_yields_chunks
    Provider.runner = FakeRunner.new(CodexOutput.reply('pong'))
    pieces = []
    reply = chat.ask('ping') { |chunk| pieces << chunk.content }

    assert_equal ['pong'], pieces
    assert_equal 'pong', reply.content
  end

  def test_schema_is_written_to_a_file
    Provider.runner = FakeRunner.new(CodexOutput.reply('{"ok":true}'))
    schema = { type: 'object', properties: { ok: { type: 'boolean' } } }
    reply = chat.with_schema(schema).ask('x')
    argv = Provider.runner.calls.first[:argv]
    path = argv[argv.index('--output-schema') + 1]

    assert_equal '{"ok":true}', reply.content
    assert_match(/ruby_llm-codex-schema-.*\.json\z/, path)
  end

  def test_tools_are_rejected_and_errors_surface
    Provider.runner = FakeRunner.new(CodexOutput.reply('ok'))
    tool = Class.new(RubyLLM::Tool) do
      description 'noop'
      def execute = 'x'
    end

    assert_raises(Provider::UnsupportedFeatureError) { chat.with_tools(tool).ask('x') }
    Provider.runner = FakeRunner.new([CodexOutput.turn_failed('nope')])
    assert_raises(Provider::Error) { chat.ask('x') }
  end

  def test_helpers
    assert_equal 'o3', Provider.model_id('o3')
    assert_equal 'high', Provider.effort_for(Struct.new(:effort).new(:high))
    assert_nil Provider.effort_for(Struct.new(:effort).new(:max))
  end
end
