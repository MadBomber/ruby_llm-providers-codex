# ruby_llm-providers-codex

A [RubyLLM](https://rubyllm.com) provider that uses the **OpenAI Codex CLI Agent Harness**
as a provider of models. Each completion runs the CLI tool `codex exec` non-interactively,
writes the prompt to its stdin and reads the JSON event stream from stdout.

This is deliberately *not* an isolated stand-in for the OpenAI API. The agent
keeps what makes it an agent: its own tools, sandbox, config and MCP servers,
and it works in the current directory. Multi-turn chats resume the same Codex
thread, so the agent keeps its context between turns.

## Requirements

- Ruby 3.2 or newer
- RubyLLM 2.1 or newer
- The Codex CLI on your PATH (`codex --version`), logged in with
  `codex login`. No API key is read by this gem.

## Installation

```ruby
gem 'ruby_llm-providers-codex', require: 'ruby_llm/providers/codex'
```

The provider registers itself as `:codex` when required and works with no
configuration at all:

```ruby
require 'ruby_llm/providers/codex'

chat = RubyLLM.chat(model: 'default', provider: :codex)
puts chat.ask('Read README.md and tell me what this gem does.').content
```

## Examples

The [examples](examples/) directory holds three small demo applications. Each
prints the prompt it sends and the reply it receives, and all of them point the
agent at this gem's own root directory, hold it to the read-only sandbox, and
only ask it to read files.

| Demo | Shows |
|---|---|
| [`01_basic.rb`](examples/01_basic.rb) | One question, one answer, with the token counts for the turn |
| [`02_session.rb`](examples/02_session.rb) | A first question that starts a Codex thread, then follow-ups that resume it; the thread id is printed after each turn |
| [`03_chat_with_streaming.rb`](examples/03_chat_with_streaming.rb) | A reply streamed as the agent produces it, then an interactive chat loop on the same thread |

Shared setup lives in [`common.rb`](examples/common.rb). Run a demo from the
gem root with Bundler, or directly from any directory:

```bash
bundle exec ruby examples/01_basic.rb
examples/02_session.rb
CODEX_MODEL=gpt-5-codex examples/03_chat_with_streaming.rb
```

## Configuration

Every option can be set in two places. `RubyLLM.configure` sets the global
default for every chat that uses this provider:

```ruby
RubyLLM.configure do |config|
  config.codex_command = 'codex'
  config.codex_cwd     = '/path/to/project'
  config.codex_timeout = 600
  config.codex_sandbox = 'workspace-write'
  config.codex_args    = ['--profile', 'review']
  config.codex_env     = { 'NO_COLOR' => '1' }
  config.codex_resume  = true
end
```

`with_provider_options` sets the same keys, without the `codex_` prefix, for
one chat. A per-chat value wins over the global one, and the global value wins
over the built-in default:

```ruby
chat = RubyLLM.chat(model: 'default', provider: :codex)
          .with_provider_options(codex: { cwd: '/path/to/project', sandbox: 'read-only' })
```

### Options

| Option | Default | Meaning |
|---|---|---|
| `command` | `codex` | CLI executable; a bare name is looked up on PATH, or give a full path |
| `cwd` | current directory | Directory the agent works in; relative paths in prompts and file edits resolve here |
| `timeout` | `600` | Seconds before the whole process group is killed; `nil` or `0` disables the timeout |
| `sandbox` | CLI default | Passed as `--sandbox` when a thread starts: `read-only`, `workspace-write` or `danger-full-access` |
| `args` | none | Extra CLI arguments appended to every invocation, as an array or a shell-style string |
| `env` | none | Extra environment variables for the CLI process, as a hash; keys and values are stringified |
| `resume` | `true` | Reuse the Codex thread across turns; `false` starts a fresh thread for every completion |
| `session_id` | none | Per-chat only: continue this thread regardless of the transcript (see Sessions) |

### Working directory

The agent reads and edits files relative to `cwd`, so set it to the project
you want worked on rather than relying on wherever your Ruby process happens
to run. The gem passes `--skip-git-repo-check`, so `cwd` does not have to be
inside a git repository.

### Sandbox

Codex runs every model-generated command under its sandbox policy, and
`sandbox` picks it: `read-only` lets the agent inspect files and run harmless
commands but change nothing, `workspace-write` lets it edit files under `cwd`,
and `danger-full-access` turns the sandbox off. The flag is sent only when a
thread starts; a resumed thread keeps the policy it began with. An invalid
value raises `ArgumentError` before the CLI is run.

### Extra CLI arguments

`args` takes either form and hands the result straight to the CLI after the
flags this gem sets itself:

```ruby
config.codex_args = ['--profile', 'review', '-c', 'approval_policy="never"']
config.codex_args = '--profile review -c approval_policy="never"'   # split with shell rules
```

Common uses are `--profile` to select a profile from `~/.codex/config.toml`
and `-c key=value` to override any single config key. Do not pass `--json`,
`--model`, `--sandbox` or `--output-schema` here, since the gem sets those
from the other options.

### Instructions

RubyLLM instructions (`chat.with_instructions`) are sent as the
`developer_instructions` config value when a thread starts, and are not
repeated on resumed turns. Changing the instructions mid-chat therefore starts
a new thread.

### Timeout

`timeout` covers the whole completion, including every command the agent
runs along the way. When it passes, the process group gets TERM, then KILL
after a two-second grace period, and the completion raises
`RubyLLM::Providers::Codex::TimeoutError`. Agentic work on a large repository
can legitimately take minutes, so raise it, or disable it with `nil`, for
long tasks.

## Models

The model id goes straight to `codex --model`. The id `default` (or an empty
id) sends no `--model` flag and lets the CLI choose, which honours the model
set in the active Codex profile.

## Sessions

RubyLLM hands the provider the whole transcript on every turn. When the
transcript minus the newest message matches what the Codex thread already
saw, only the new message is sent with `codex exec resume <thread id>`. Any
other shape (rewound or edited history, a cleared chat, changed instructions)
starts a fresh thread with the conversation replayed as a tagged transcript.

```ruby
chat.with_provider_options(codex: { resume: false })      # fresh thread every turn
chat.with_provider_options(codex: { session_id: 'uuid' }) # continue a known thread
chat.provider.session.id                                  # the thread in use
```

## What is supported

| Feature | How |
|---|---|
| Text, system prompts, multi-turn | Instructions go in as `developer_instructions`; see Sessions |
| Streaming | Each completed agent message is yielded as one chunk; the last one is the reply |
| Structured output (`with_schema`) | `--output-schema` via a temporary file |
| `with_thinking(effort:)` | `model_reasoning_effort` (minimal, low, medium, high, xhigh) |
| Token counts | From `turn.completed`: input, cached input, output and reasoning tokens |
| Attachments | Noted in the prompt as `[Attached file 'name': path]`; the agent opens local files itself |
| RubyLLM tools (`with_tools`) | **Not supported**: raises `UnsupportedFeatureError`. The provider class answers `accepts_tools?` with `false` so a host application can skip attaching tools |
| temperature, max tokens | Ignored (logged at debug level) |

## Safety

Codex runs model-generated commands under its sandbox policy. Set `sandbox`
explicitly for anything beyond read-only work.

## Development

```bash
bundle install
asgard test_verbose       # offline: the CLI is replaced by a fake runner
asgard quality            # tests, rubocop, flog, flay, reek, ...
```
