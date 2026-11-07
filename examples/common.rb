# frozen_string_literal: true

# common.rb
#
# Shared setup for the numbered demos in this directory: anchors Bundler to
# the gem root, loads the gem, configures the OpenAI Codex provider, and defines
# the small helpers the demos use to print each prompt and reply.
#
# Requirements: the `codex` CLI on $PATH and logged in. The gem reads no API
# key of its own.
#
# Pick a model with CODEX_MODEL (default lets the CLI choose).

# The workspace .envrc exports a relative BUNDLE_GEMFILE (Gemfile or Gemfile.local),
# which Bundler would resolve against the current directory. Anchor it to the
# gem root so the demos run from any directory.
GEM_ROOT = File.expand_path('..', __dir__)
gemfile  = ENV.fetch('BUNDLE_GEMFILE', 'Gemfile')
ENV['BUNDLE_GEMFILE'] = File.expand_path(gemfile, GEM_ROOT) unless File.absolute_path?(gemfile)

require 'bundler/setup'
require 'ruby_llm/providers/codex'

MODEL = ENV.fetch('CODEX_MODEL', 'default')

RubyLLM.configure do |config|
  config.codex_cwd     = GEM_ROOT # the agent works in the gem's root directory
  config.codex_timeout = 300
  config.codex_sandbox = 'read-only' # new threads only; the demos never need to write
end

$stdout.sync = true # so prompts and streamed chunks appear as they happen

# A chat bound to the OpenAI Codex provider, told to keep its answers short.
def new_chat
  RubyLLM.chat(model: MODEL, provider: :codex)
         .with_instructions('Answer in plain prose, in no more than three sentences.')
end

def banner(title) = puts "\n#{'=' * 72}\n== #{title}\n#{'=' * 72}\n\n"

def show_prompt(text) = puts "you>   #{text}\n\n"

# The CLI session the provider is resuming for this chat.
def session_id(chat) = chat.provider.session.id

# Sends +prompt+ and prints the whole reply once it arrives.
def ask(chat, prompt)
  show_prompt(prompt)
  response = chat.ask(prompt)
  puts "agent> #{response.content}"
  response
end

# Sends +prompt+ and prints the reply chunk by chunk as the agent produces it.
def ask_streaming(chat, prompt)
  show_prompt(prompt)
  print 'agent> '
  response = chat.ask(prompt) { |chunk| print chunk.content if chunk.content }
  puts
  response
end

# Runs the demo body, reporting provider errors on stderr with a nonzero exit.
def demo
  yield
rescue RubyLLM::Error => e
  # `warn` is silenced by Bundler ($VERBOSE is nil under `bundle exec`), so write to $stderr directly.
  $stderr.puts e.message # rubocop:disable Style/StderrPuts
  exit 1
end
