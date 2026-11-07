# frozen_string_literal: true

require 'digest'
require 'json'

module RubyLLM
  module Providers
    class Codex < Provider
      # Renders RubyLLM messages into the text the CLI reads from stdin, and
      # fingerprints transcripts so Session can tell whether a CLI session
      # already holds the earlier turns.
      class Transcript
        REPLAY_PREAMBLE = "The conversation so far follows. Continue it by writing the assistant's next reply " \
                          "to the last turn. Do not repeat the tags.\n\n"
        EMPTY = '(empty message)'

        class << self
          def fingerprint(messages)
            Digest::SHA256.hexdigest(JSON.generate(messages.map { |message| summary(message) }))
          end

          def summary(message)
            {
              role: message.role.to_s,
              content: message.content.to_s,
              tool_call_id: message.tool_call_id,
              tool_calls: tool_calls(message).map { |call| [call.id, call.name, call.arguments] },
              attachments: attachments(message).map { |attachment| attachment_note(attachment) }
            }
          end

          # The message text plus a note per attachment naming its location;
          # the agent can open local files with its own tools.
          def text_of(message)
            parts = [message.content.to_s]
            attachments(message).each { |attachment| parts << attachment_note(attachment) }
            parts.reject(&:empty?).join("\n").strip
          end

          def attachment_note(attachment)
            source = attachment.respond_to?(:source) ? attachment.source : attachment
            name = attachment.respond_to?(:filename) ? attachment.filename : nil
            location = source.respond_to?(:to_path) ? source.to_path : source.to_s
            "[Attached file#{" '#{name}'" if name}: #{location}]"
          end

          def attachments(message)
            message.respond_to?(:attachments) ? Array(message.attachments) : []
          end

          def tool_calls(message)
            calls = message.respond_to?(:tool_calls) ? message.tool_calls : nil
            calls.respond_to?(:values) ? calls.values : Array(calls)
          end
        end

        def initialize(messages)
          @system, @turns = messages.partition { |message| message.role == :system }
        end

        # All system messages joined, or nil when there are none.
        def system_prompt
          text = @system.map { |message| self.class.text_of(message) }.reject(&:empty?).join("\n\n")
          text.empty? ? nil : text
        end

        # A lone user turn goes through as-is; anything longer becomes a
        # tagged replay of the conversation.
        def prompt
          return EMPTY if @turns.empty?
          return single_turn if @turns.one? && @turns.first.role == :user

          REPLAY_PREAMBLE + @turns.map { |message| turn(message) }.join("\n")
        end

        private

        def single_turn
          text = self.class.text_of(@turns.first)
          text.empty? ? EMPTY : text
        end

        def turn(message)
          body = self.class.text_of(message)
          case message.role
          when :tool then "<tool_result id=\"#{message.tool_call_id}\">\n#{body}\n</tool_result>"
          when :assistant then "<assistant>\n#{body}#{tool_calls_text(message)}\n</assistant>"
          else "<user>\n#{body}\n</user>"
          end
        end

        def tool_calls_text(message)
          self.class.tool_calls(message).map do |call|
            "\n<tool_call id=\"#{call.id}\" name=\"#{call.name}\">#{JSON.generate(call.arguments)}</tool_call>"
          end.join
        end
      end
    end
  end
end
