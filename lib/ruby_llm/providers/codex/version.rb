# frozen_string_literal: true

module RubyLLM
  module Providers
    # Version of the ruby_llm-providers-codex gem. Kept in its own file
    # so the gemspec can read the literal without loading the provider.
    class Codex < Provider
      VERSION = '0.0.1'

      def self.version
        VERSION
      end
    end
  end
end
