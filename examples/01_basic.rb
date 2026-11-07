#!/usr/bin/env ruby
# frozen_string_literal: true

# 01_basic.rb
#
# The simplest use of RubyLLM with the OpenAI Codex provider: one question, one
# answer. The prompt asks the agent to read a file in the gem root, which is
# something an ordinary model API cannot do.
#
# Run it from anywhere:
#   bundle exec ruby examples/01_basic.rb
#   examples/01_basic.rb

require_relative 'common'

demo do
  banner "Basic one-shot question  (model: #{MODEL})"

  chat     = new_chat
  response = ask(chat, 'Read README.md and tell me what this gem does.')

  puts "\ntokens: #{response.tokens.input.to_i} in, #{response.tokens.output.to_i} out"
end
