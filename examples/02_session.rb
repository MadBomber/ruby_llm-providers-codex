#!/usr/bin/env ruby
# frozen_string_literal: true

# 02_session.rb
#
# Multi-turn conversation with the OpenAI Codex agent. The first question starts
# a CLI session; the follow-up is sent with only the new message and the
# session id, so the agent keeps its context, tool results and plan between
# turns instead of re-reading the whole transcript.
#
# Run it from anywhere:
#   bundle exec ruby examples/02_session.rb
#   examples/02_session.rb

require_relative 'common'

demo do
  chat = new_chat

  banner '1. One-shot question (starts the agent session)'
  ask(chat, 'Read README.md and tell me what this gem does.')
  puts "\nsession: #{session_id(chat)}"

  banner '2. Follow-up (resumes the same session)'
  ask(chat, 'Which file under lib/ spawns the CLI process? Name it and say what it does.')
  puts "\nsession: #{session_id(chat)} (unchanged)"

  banner '3. Another follow-up, relying on the earlier answers'
  ask(chat, 'Summarize what you have told me so far as a haiku.')
  puts "\nsession: #{session_id(chat)} (unchanged)"
end
