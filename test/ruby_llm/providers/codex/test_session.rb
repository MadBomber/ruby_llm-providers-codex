# frozen_string_literal: true

require 'test_helper'

class TestCodexSession < Minitest::Test
  Session = RubyLLM::Providers::Codex::Session

  def setup
    @session = Session.new
    @q1 = user_message('q1')
    @a1 = assistant_message('a1')
    @q2 = user_message('q2')
  end

  def test_first_call_is_fresh
    plan = @session.plan([@q1])
    assert_equal [@q1], plan.messages
    refute_predicate plan, :resume?
  end

  def test_resumes_when_history_matches
    @session.record([@q1], @a1, id: 'sess-1')
    plan = @session.plan([@q1, @a1, @q2])
    assert_equal [@q2], plan.messages
    assert_equal 'sess-1', plan.resume_id
  end

  def test_fresh_when_history_diverges
    @session.record([@q1], @a1, id: 'sess-1')
    edited = [@q1, assistant_message('different'), @q2]
    plan = @session.plan(edited)
    assert_equal edited, plan.messages
    refute_predicate plan, :resume?
  end

  def test_fresh_after_reset_or_cleared_history
    @session.record([@q1], @a1, id: 'sess-1')
    refute_predicate @session.plan([@q2]), :resume?
    @session.reset!
    assert_nil @session.id
    refute_predicate @session.plan([@q1, @a1, @q2]), :resume?
  end

  def test_resume_can_be_disabled_or_forced
    @session.record([@q1], @a1, id: 'sess-1')
    refute_predicate @session.plan([@q1, @a1, @q2], resume: false), :resume?
    forced = @session.plan([@q1, @a1, @q2], session_id: 'other')
    assert_equal 'other', forced.resume_id
    assert_equal [@q2], forced.messages
  end

  def test_no_session_id_means_no_resume
    @session.record([@q1], @a1, id: nil)
    refute_predicate @session.plan([@q1, @a1, @q2]), :resume?
  end

  def test_rejects_empty
    assert_raises(ArgumentError) { @session.plan([]) }
  end
end
