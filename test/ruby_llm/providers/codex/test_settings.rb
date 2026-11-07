# frozen_string_literal: true

require 'test_helper'

class TestCodexSettings < Minitest::Test
  Settings = RubyLLM::Providers::Codex::Settings

  def config(**values)
    RubyLLM::Configuration.new.tap do |c|
      values.each { |key, value| c.public_send(:"codex_#{key}=", value) }
    end
  end

  def test_defaults
    settings = Settings.new(config)

    assert_equal 'codex', settings.command
    assert_nil settings.cwd
    assert_in_delta 600.0, settings.timeout
    assert_nil settings.sandbox
    assert_empty settings.args
    assert_empty settings.env
    assert_nil settings.session_id
    assert_predicate settings, :resume?
  end

  def test_config_values
    settings = Settings.new(config(command: '/opt/codex', cwd: '/tmp', timeout: 30, sandbox: :'workspace-write',
                                   args: '--profile fast', env: { FOO: 1 }, resume: false))

    assert_equal '/opt/codex', settings.command
    assert_equal '/tmp', settings.cwd
    assert_in_delta 30.0, settings.timeout
    assert_equal 'workspace-write', settings.sandbox
    assert_equal ['--profile', 'fast'], settings.args
    assert_equal({ 'FOO' => '1' }, settings.env)
    refute_predicate settings, :resume?
  end

  def test_provider_options_win
    options = { codex: { 'command' => 'c2', timeout: nil, args: %w[--oss], session_id: 'abc' } }
    settings = Settings.new(config(command: 'c1', timeout: 5), options)

    assert_equal 'c2', settings.command
    assert_nil settings.timeout
    assert_equal ['--oss'], settings.args
    assert_equal 'abc', settings.session_id
  end

  def test_validation
    assert_nil Settings.positive_or_nil(0)
    assert_raises(ArgumentError) { Settings.sandbox('wide-open') }
    assert_raises(ArgumentError) { Settings.namespaced({ codex: 'nope' }) }
    assert_empty Settings.namespaced(nil)
  end
end
