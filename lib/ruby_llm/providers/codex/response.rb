# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class Codex < Provider
      # Reads `codex exec --json` events line by line. Each completed
      # agent_message item is streamed as a Chunk; the last one is the reply.
      # turn.completed carries the token usage.
      class Response
        attr_reader :session_id, :model_id, :events

        def initialize(model:, schema: nil)
          @model  = model
          @schema = schema
          @events = []
          @text   = nil
          @usage  = {}
          @error  = nil
        end

        # @param line [String] one line of stdout
        # @yield [RubyLLM::Chunk] a completed agent message
        # @return [Hash, nil] the parsed event, or nil for non-JSON lines
        def ingest(line)
          event = self.class.parse(line)
          return nil unless event

          @events << event
          case event['type']
          when 'thread.started' then @session_id = event['thread_id']
          when 'item.completed'
            text = agent_text(event)
            if text
              @text = text
              yield chunk(text) if block_given?
            end
          when 'turn.completed' then @usage = event['usage'] || {}
          when 'turn.failed' then @error = event.dig('error', 'message') || event['error'].to_s
          when 'error' then @error = event['message'].to_s
          end
          event
        end

        # @param run [Runner::Result, nil] used for diagnostics when no reply arrived
        # @return [RubyLLM::Message]
        def message(run = nil)
          raise Error, "codex exec failed: #{@error}" if @error

          raise_without_result!(run) if @text.nil?

          total_input = @usage['input_tokens']
          cached = @usage['cached_input_tokens']
          Message.new(
            role: :assistant,
            content: @text,
            model: @model,
            input_tokens: total_input && [total_input.to_i - cached.to_i, 0].max,
            output_tokens: @usage['output_tokens'],
            cache_read_tokens: cached,
            cache_write_tokens: @usage['cache_write_input_tokens'],
            thinking_tokens: @usage['reasoning_output_tokens'],
            finish_reason: :stop,
            raw: { 'thread_id' => @session_id, 'usage' => @usage, 'events' => @events }
          )
        end

        def self.parse(line)
          text = line.to_s.strip
          return nil unless text.start_with?('{')

          JSON.parse(text)
        rescue JSON::ParserError
          RubyLLM.logger.debug { "codex: non-JSON output #{text.inspect}" }
          nil
        end

        private

        def agent_text(event)
          item = event['item'] || {}
          item['text'] if item['type'] == 'agent_message'
        end

        def raise_without_result!(run)
          status = run&.status&.exitstatus
          stderr = run&.stderr.to_s.strip
          raise Error,
                "codex exec exited#{" (#{status})" if status} without a reply#{": #{stderr}" unless stderr.empty?}"
        end

        def chunk(text)
          Chunk.new(role: :assistant, content: text, model: @model)
        end
      end
    end
  end
end
