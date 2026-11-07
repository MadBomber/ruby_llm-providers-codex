#!/usr/bin/env ruby
# frozen_string_literal: true

# 03_chat_with_streaming.rb
#
# Streaming with the OpenAI Codex provider: first a scripted question whose
# reply is printed chunk by chunk as the agent produces it, then an
# interactive chat loop on the same session where every reply streams.
#
# Run it from anywhere:
#   bundle exec ruby examples/03_chat_with_streaming.rb
#   examples/03_chat_with_streaming.rb
#
# Ctrl-D, 'exit' or 'quit' ends the chat. Input may also be piped in.

require_relative 'common'

# Reads one prompt from the terminal; nil on EOF or an exit word.
def read_prompt
  print 'you>   '
  line = $stdin.gets
  return if line.nil?

  prompt = line.strip
  puts prompt unless $stdin.tty? # echo piped input so the transcript reads naturally
  return if %w[exit quit].include?(prompt.downcase)

  prompt
end

# Chats with the agent until EOF or an exit word, streaming each reply.
def chat_loop(chat)
  puts "Type a message and press Enter. Ctrl-D, 'exit' or 'quit' ends the chat.\n\n"
  while (prompt = read_prompt)
    next if prompt.empty?

    print 'agent> '
    chat.ask(prompt) { |chunk| print chunk.content if chunk.content }
    puts "\n"
  end
end

demo do
  chat = new_chat

  banner '1. Streamed reply'
  response = ask_streaming(chat, 'Read README.md and describe this gem in three short sentences.')
  puts "\ntokens: #{response.tokens.input.to_i} in, #{response.tokens.output.to_i} out"

  banner "2. Interactive chat  (model: #{MODEL}, session: #{session_id(chat)})"
  chat_loop(chat)
  puts "\nbye"
rescue Interrupt
  puts "\nbye"
end
