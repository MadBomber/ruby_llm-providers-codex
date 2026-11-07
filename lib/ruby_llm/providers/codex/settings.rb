# frozen_string_literal: true

require 'shellwords'

module RubyLLM
  module Providers
    class Codex < Provider
      # The settings for one completion. Each value comes from, in order of
      # precedence, chat.with_provider_options(codex: {...}), the
      # RubyLLM.config.codex_* option, then the default here.
      class Settings
        DEFAULT_COMMAND = 'codex'
        DEFAULT_TIMEOUT = 600
        SANDBOXES = %w[read-only workspace-write danger-full-access].freeze

        attr_reader :command, :cwd, :timeout, :sandbox, :args, :env, :session_id

        def initialize(config, provider_options = {})
          opts = self.class.namespaced(provider_options)
          @command    = opts.fetch(:command) { config.codex_command } || DEFAULT_COMMAND
          @cwd        = opts.fetch(:cwd) { config.codex_cwd }
          @timeout    = self.class.positive_or_nil(opts.fetch(:timeout) { timeout_default(config) })
          @sandbox    = self.class.sandbox(opts.fetch(:sandbox) { config.codex_sandbox })
          @args       = self.class.split_args(opts.fetch(:args) { config.codex_args })
          @env        = self.class.stringify(opts.fetch(:env) { config.codex_env })
          @session_id = opts[:session_id]
          @resume     = opts.fetch(:resume) { config.codex_resume.nil? || config.codex_resume }
        end

        # False when every completion must start a fresh CLI session.
        def resume?
          @resume ? true : false
        end

        class << self
          # The codex: sub-hash of provider_options with symbol keys.
          def namespaced(provider_options)
            return {} unless provider_options.is_a?(Hash)

            raw = provider_options[:codex] || provider_options['codex'] || {}
            raise ArgumentError, 'provider_options[:codex] must be a Hash' unless raw.is_a?(Hash)

            raw.transform_keys(&:to_sym)
          end

          # A positive number of seconds, or nil for "no timeout".
          def positive_or_nil(value)
            return nil if value.nil?

            number = Float(value)
            number.positive? ? number : nil
          end

          # Extra CLI arguments given as an array or a shell-style string.
          def split_args(value)
            case value
            when nil then []
            when String then Shellwords.split(value)
            else Array(value).map(&:to_s)
            end
          end

          def sandbox(value)
            return nil if value.nil?

            text = value.to_s
            return text if SANDBOXES.include?(text)

            raise ArgumentError, "codex sandbox must be one of #{SANDBOXES.join(', ')}"
          end

          def stringify(value)
            (value || {}).to_h.to_h { |key, item| [key.to_s, item.to_s] }
          end
        end

        private

        def timeout_default(config)
          config.codex_timeout.nil? ? DEFAULT_TIMEOUT : config.codex_timeout
        end
      end
    end
  end
end
