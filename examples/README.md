# Examples

Demo apps showing the `ruby_llm-providers-codex` gem driving the OpenAI Codex
agent through RubyLLM. Shared setup lives in `common.rb`, which every demo
loads with `require_relative 'common'`.

## Running a demo

```sh
bundle exec ruby examples/01_basic.rb   # from the gem root
examples/01_basic.rb                    # or run it directly, from any directory
```

The `codex` CLI must be on `$PATH` and logged in; the gem reads no API key of
its own. The demos point the agent at this gem's root directory and only ask
it to read files. Choose a model with `CODEX_MODEL` (default lets the CLI choose).

## Demos

| File | Shows |
| --- | --- |
| `01_basic.rb` | One question, one answer: the prompt sent and the reply received. |
| `02_session.rb` | A one-shot question that starts the agent session, then follow-ups that resume it; the session id is printed after each turn. |
| `03_chat_with_streaming.rb` | A reply streamed chunk by chunk, then an interactive chat loop on the same session (Ctrl-D, `exit` or `quit` ends it). |
