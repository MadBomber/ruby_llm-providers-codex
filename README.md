# ruby_llm-providers-codex

A [RubyLLM](https://rubyllm.com) provider that uses the **OpenAI Codex agent**
as the model. Each completion runs `codex exec` non-interactively, writes the
prompt to its stdin and reads the JSON event stream from stdout.

This is deliberately *not* an isolated stand-in for the OpenAI API. The agent
keeps what makes it an agent: its own tools, sandbox, config and MCP servers,
and it works in the current directory. Multi-turn chats resume the same Codex
thread, so the agent keeps its context between turns.

```ruby
require 'ruby_llm/providers/codex'

chat = RubyLLM.chat(model: 'default', provider: :codex)
chat.ask('What does the Rakefile in this directory do?')
chat.ask('Add a `lint` task to it') { |chunk| print chunk.content }
```

With [aia](https://github.com/madbomber/aia) the provider is picked from the
model prefix:

```bash
aia --model codex/default review_prompt
aia --model claude_code/sonnet=implementer,codex/default=reviewer --consensus review
```

## Requirements

- Ruby 3.2 or newer
- RubyLLM 2.1 or newer
- The Codex CLI on your PATH (`codex --version`), logged in with
  `codex login`. No API key is read by this gem.

## Installation

```ruby
gem 'ruby_llm-providers-codex', require: 'ruby_llm/providers/codex'
```

The provider registers itself as `:codex` when required.

## Models

The part after the slash goes straight to `codex --model`. The id `default`
(or an empty id) sends no `--model` flag and lets the CLI choose.

## Sessions

RubyLLM hands the provider the whole transcript on every turn. When the
transcript minus the newest message matches what the Codex thread already
saw, only the new message is sent with `codex exec resume <thread id>`. Any
other shape (rewound or edited history, a cleared chat, a changed system
prompt) starts a fresh thread with the conversation replayed as a tagged
transcript.

```ruby
chat.with_provider_options(codex: { resume: false })      # fresh thread every turn
chat.with_provider_options(codex: { session_id: 'uuid' }) # continue a known thread
```

## Configuration

Global options are `RubyLLM.config.codex_*`; the same keys can be set per
chat with `with_provider_options(codex: { ... })`.

| Option | Default | Meaning |
|---|---|---|
| `command` | `codex` | CLI executable |
| `cwd` | current directory | Directory the agent works in |
| `timeout` | `600` | Seconds before the process group is killed; `nil` or `0` disables |
| `sandbox` | CLI default | `--sandbox`: `read-only`, `workspace-write` or `danger-full-access` (new threads only) |
| `args` | none | Extra CLI arguments, array or shell string (`--profile`, `-c key=value`, ...) |
| `env` | none | Extra environment variables for the process |
| `resume` | `true` | Reuse the thread across turns |
| `session_id` | none | Per-request only: resume this thread id |

## What is supported

| Feature | How |
|---|---|
| Text, system prompts, multi-turn | Instructions go in as `developer_instructions`; see Sessions |
| Streaming | Each completed agent message is yielded as one chunk; the last one is the reply |
| Structured output (`with_schema`) | `--output-schema` via a temporary file |
| `with_thinking(effort:)` | `model_reasoning_effort` (minimal, low, medium, high, xhigh) |
| Token counts | From `turn.completed`: input, cached input, output and reasoning tokens |
| Attachments | Noted in the prompt as `[Attached file 'name': path]`; the agent opens local files itself |
| RubyLLM tools (`with_tools`) | **Not supported**: raises `UnsupportedFeatureError`. The provider class answers `accepts_tools?` with `false` so hosts such as aia can skip attaching tools |
| temperature, max tokens | Ignored (logged at debug level) |

## Safety

Codex runs model-generated commands under its sandbox policy. Set `sandbox`
explicitly for anything beyond read-only work.

## Development

```bash
bundle install
bundle exec rake test     # offline: the CLI is replaced by a fake runner
bundle exec rubocop
```
