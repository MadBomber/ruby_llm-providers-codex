# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestCodexTranscript < Minitest::Test
  Transcript = RubyLLM::Providers::Codex::Transcript

  def test_single_user_turn_is_verbatim
    transcript = Transcript.new([system_message('Be brief.'), user_message('hello')])
    assert_equal 'hello', transcript.prompt
    assert_equal 'Be brief.', transcript.system_prompt
  end

  def test_no_system_prompt_is_nil
    assert_nil Transcript.new([user_message('x')]).system_prompt
  end

  def test_empty_turns
    assert_equal Transcript::EMPTY, Transcript.new([system_message('s')]).prompt
    assert_equal Transcript::EMPTY, Transcript.new([user_message('')]).prompt
  end

  def test_multi_turn_replay
    messages = [system_message('S'), user_message('q1'), assistant_message('a1'), user_message('q2')]
    prompt = Transcript.new(messages).prompt
    assert prompt.start_with?(Transcript::REPLAY_PREAMBLE)
    assert_includes prompt, "<user>\nq1\n</user>\n<assistant>\na1\n</assistant>\n<user>\nq2\n</user>"
    refute_includes prompt, 'S'
  end

  def test_tool_turns_are_tagged
    call = RubyLLM::ToolCall.new(id: 'c1', name: 'weather', arguments: { city: 'Austin' })
    messages = [user_message('q'), RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'c1' => call }),
                RubyLLM::Message.new(role: :tool, content: 'sunny', tool_call_id: 'c1'), user_message('and?')]
    prompt = Transcript.new(messages).prompt
    assert_includes prompt, '<tool_call id="c1" name="weather">{"city":"Austin"}</tool_call>'
    assert_includes prompt, "<tool_result id=\"c1\">\nsunny\n</tool_result>"
  end

  def test_attachments_become_notes
    Tempfile.create(['note', '.txt']) do |file|
      file.write('hi')
      file.flush
      message = user_message('read this', attachments: [file.path])
      text = Transcript.text_of(message)
      assert_includes text, 'read this'
      assert_includes text, "[Attached file '#{File.basename(file.path)}': #{file.path}]"
    end
  end

  def test_fingerprint_is_stable_and_sensitive
    a = [user_message('q'), assistant_message('a')]
    b = [user_message('q'), assistant_message('a')]
    c = [user_message('q'), assistant_message('b')]
    assert_equal Transcript.fingerprint(a), Transcript.fingerprint(b)
    refute_equal Transcript.fingerprint(a), Transcript.fingerprint(c)
    assert_equal Transcript.fingerprint([]), Transcript.fingerprint([])
  end
end
