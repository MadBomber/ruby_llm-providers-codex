# frozen_string_literal: true

require 'test_helper'

class TestCodexCommand < Minitest::Test
  Command = RubyLLM::Providers::Codex::Command
  Settings = RubyLLM::Providers::Codex::Settings

  def command(provider_options = {})
    Command.new(Settings.new(RubyLLM::Configuration.new, provider_options))
  end

  def test_plain_request
    assert_equal %w[codex exec --json --skip-git-repo-check -], command.build
  end

  def test_fresh_thread_with_everything
    argv = command(codex: { sandbox: 'read-only', args: ['--profile', 'p'] }).build(
      model: 'gpt-5', system_prompt: "Be terse.\nAlways.", schema_path: '/tmp/s.json', effort: 'high'
    )
    expected = ['codex', 'exec', '--json', '--skip-git-repo-check', '--model', 'gpt-5', '--sandbox', 'read-only',
                '--config', 'developer_instructions="Be terse.\nAlways."', '--output-schema', '/tmp/s.json',
                '--config', 'model_reasoning_effort="high"', '--profile', 'p', '-']

    assert_equal expected, argv
  end

  def test_resume_sends_no_instructions
    argv = command(codex: { sandbox: 'read-only' }).build(model: 'default', resume_id: 't-9', system_prompt: 'X')

    assert_equal %w[codex exec resume --json --skip-git-repo-check t-9 -], argv
  end

  def test_toml_literals
    assert_equal '"a\"b"', Command.toml_literal('a"b')
    assert_equal 'true', Command.toml_literal(true)
    assert_equal '3', Command.toml_literal(3)
    assert_equal '["x", 1]', Command.toml_literal(['x', 1])
    assert_raises(ArgumentError) { Command.toml_literal(Object.new) }
    assert_equal 'k="v"', Command.toml_assignment('k', 'v')
  end

  def test_named_and_schema_helpers
    refute Command.named?('default')
    assert Command.named?('o3')
    assert_equal({ 'a' => 1 }, Command.schema_definition({ 'schema' => { 'a' => 1 } }))
    assert_equal({ type: 'x' }, Command.schema_definition({ type: 'x' }))
  end
end
