# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class Codex < Provider
      # Builds the argv for one `codex exec` (or `codex exec resume`) call.
      # The prompt itself always arrives on stdin, signalled by the final "-".
      class Command
        EFFORTS = %w[minimal low medium high xhigh].freeze

        def initialize(settings)
          @settings = settings
        end

        # @param model [String, nil] model id; "default" means the CLI's own choice
        # @param resume_id [String, nil] thread id to continue
        # @param system_prompt [String, nil] sent as developer_instructions when starting a thread
        # @param schema_path [String, nil] file holding a JSON Schema for --output-schema
        # @param effort [String, nil] one of EFFORTS
        # @return [Array<String>]
        def build(model: nil, resume_id: nil, system_prompt: nil, schema_path: nil, effort: nil)
          argv = [@settings.command, 'exec']
          argv << 'resume' if resume_id
          argv.push('--json', '--skip-git-repo-check')
          argv.push('--model', model.to_s) if self.class.named?(model)
          argv.concat(fresh_thread_args(system_prompt, schema_path)) unless resume_id
          argv.push('--config', self.class.toml_assignment('model_reasoning_effort', effort)) if effort
          argv.concat(@settings.args)
          argv << resume_id if resume_id
          argv << '-'
        end

        class << self
          def named?(model)
            !(model.nil? || model.to_s.empty? || model.to_s == DEFAULT_MODEL)
          end

          # key=value for codex --config, with the value as a TOML literal.
          def toml_assignment(key, value)
            "#{key}=#{toml_literal(value)}"
          end

          def toml_literal(value)
            case value
            when String, Symbol then JSON.generate(value.to_s)
            when true, false, Integer, Float then value.to_s
            when Array then "[#{value.map { |item| toml_literal(item) }.join(', ')}]"
            else raise ArgumentError, "unsupported codex config value: #{value.inspect}"
            end
          end

          # The bare JSON Schema from RubyLLM's payload.
          def schema_definition(schema)
            schema[:schema] || schema['schema'] || schema
          end
        end

        private

        def fresh_thread_args(system_prompt, schema_path)
          argv = []
          argv.push('--sandbox', @settings.sandbox) if @settings.sandbox
          if system_prompt && !system_prompt.strip.empty?
            argv.push('--config', self.class.toml_assignment('developer_instructions', system_prompt))
          end
          argv.push('--output-schema', schema_path) if schema_path
          argv
        end
      end
    end
  end
end
