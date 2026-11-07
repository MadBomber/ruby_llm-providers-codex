# frozen_string_literal: true

module RubyLLM
  module Providers
    class Codex < Provider
      # Raised when the codex CLI cannot be run, exits without a result, or
      # reports an error of its own.
      class Error < RubyLLM::Error; end

      # Raised when the CLI runs past the configured timeout and is killed.
      class TimeoutError < Error; end

      # Raised for RubyLLM features the CLI cannot honour, such as tools.
      class UnsupportedFeatureError < Error; end
    end
  end
end
