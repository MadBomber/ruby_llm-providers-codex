# frozen_string_literal: true

module RubyLLM
  module Providers
    class Codex < Provider
      # Decides, per completion, whether to resume the CLI session that
      # answered the previous turn or to start a new one. A session is resumed
      # only when the transcript RubyLLM hands over, minus the newest message,
      # is exactly what that session already saw. A rewound, edited or cleared
      # history gets a fresh session replayed from the whole transcript.
      class Session
        Plan = Data.define(:messages, :resume_id) do
          def resume?
            !resume_id.nil?
          end
        end

        attr_reader :id

        def initialize
          reset!
        end

        # @param messages [Array<RubyLLM::Message>] the full RubyLLM transcript
        # @param session_id [String, nil] a caller-chosen session to continue
        # @param resume [Boolean] false forces a fresh session every time
        # @return [Plan] the messages to send and the session to resume, if any
        def plan(messages, session_id: nil, resume: true)
          raise ArgumentError, 'no messages to send' if messages.empty?
          return Plan.new(messages: [messages.last], resume_id: session_id) if session_id
          return Plan.new(messages: messages, resume_id: nil) unless resume && continues?(messages)

          Plan.new(messages: [messages.last], resume_id: @id)
        end

        # Remember which session answered, and what it has now seen.
        def record(messages, reply, id:)
          @id = id
          @fingerprint = id ? Transcript.fingerprint(messages + [reply]) : nil
        end

        def reset!
          @id = nil
          @fingerprint = nil
        end

        private

        def continues?(messages)
          return false unless @id && @fingerprint && messages.size > 1

          Transcript.fingerprint(messages[0...-1]) == @fingerprint
        end
      end
    end
  end
end
