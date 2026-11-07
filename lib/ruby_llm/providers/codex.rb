# frozen_string_literal: true

require 'ruby_llm'
require 'tempfile'
require 'ruby_llm/providers/codex/version'
require 'ruby_llm/providers/codex/errors'
require 'ruby_llm/providers/codex/settings'
require 'ruby_llm/providers/codex/command'
require 'ruby_llm/providers/codex/transcript'
require 'ruby_llm/providers/codex/session'
require 'ruby_llm/providers/codex/runner'
require 'ruby_llm/providers/codex/response'

module RubyLLM
  module Providers
    # Codex: the OpenAI Codex agent (`codex exec`) as a RubyLLM provider.
    #
    # Each completion spawns the codex CLI non-interactively, writes the
    # prompt to its stdin and reads its JSON event stream from stdout. The
    # agent keeps its own tools, config and MCP servers and works in the
    # current directory (or config.codex_cwd). Multi-turn chats resume the
    # same thread (`codex exec resume`) as long as the RubyLLM transcript
    # still matches what that thread has seen; otherwise a fresh thread is
    # started from the whole transcript.
    #
    #   require 'ruby_llm/providers/codex'
    #   chat = RubyLLM.chat(model: 'default', provider: :codex)
    #   chat.ask('Summarise the README in this directory')
    class Codex < Provider
      DEFAULT_MODEL = 'default'
      MODELS = %w[default].freeze
      CAPABILITIES = %w[streaming structured_output].freeze

      # Satisfies RubyLLM's protocol lookups; every request goes through
      # #complete below, never through a wire protocol.
      protocol :codex, RubyLLM::Protocol

      class << self
        # Anything responding to #run like Runner; tests inject fakes here.
        attr_accessor :runner

        def configuration_options
          %i[codex_command codex_cwd codex_timeout codex_sandbox codex_args codex_env codex_resume]
        end

        def configuration_requirements
          []
        end

        def local?
          true
        end

        # Any id goes straight to --model, so there is no catalog to check.
        def assume_models_exist?
          true
        end

        # The agent runs its own tools; RubyLLM tools cannot be handed to it.
        # Hosts such as aia check this before attaching tools or MCP servers.
        def accepts_tools?
          false
        end

        def display_name
          'Codex'
        end

        def model_id(model)
          model.respond_to?(:id) ? model.id : model.to_s
        end

        def effort_for(thinking)
          return nil unless thinking.respond_to?(:effort) && thinking.effort

          value = thinking.effort.to_s
          Command::EFFORTS.include?(value) ? value : nil
        end
      end

      attr_reader :session

      def initialize(config)
        super
        @session = Session.new
      end

      # Never contacted; the transport layer only needs a base URL.
      def api_base
        'cli://codex'
      end

      # Messages go to the CLI as text, so there is nothing to upload or
      # convert beforehand.
      def preprocess_messages(messages, **)
        messages
      end

      def discard_missing_uploads(_messages, _error, **)
        []
      end

      # :reek:LongParameterList -- the keyword set is RubyLLM's Provider#complete contract
      def complete(messages, model:, tools: {}, provider_options: {}, schema: nil, thinking: nil,
                   temperature: nil, max_output_tokens: nil, before_request: [], **, &block)
        reject_tools!(tools)
        log_ignored(temperature:, max_output_tokens:)
        settings   = Settings.new(@config, provider_options)
        plan       = session.plan(messages, session_id: settings.session_id, resume: settings.resume?)
        transcript = Transcript.new(plan.messages)
        with_schema_file(schema) do |schema_path|
          argv = build_argv(settings, model, transcript, plan, schema_path, thinking)
          before_request.each { |hook| hook.call({ argv: argv, prompt: transcript.prompt }) }
          response = Response.new(model: model, schema: schema)
          run = runner.run(argv, stdin: transcript.prompt, cwd: settings.cwd, timeout: settings.timeout,
                                 env: settings.env) do |line|
            response.ingest(line) { |chunk| block&.call(chunk) }
          end
          message = response.message(run)
          session.record(messages, message, id: response.session_id)
          message
        end
      end

      # A static catalog: "default" stands for the CLI's own model choice;
      # any other id is passed through to --model.
      def list_models
        MODELS.map { |id| static_model(id) }
      end

      private

      def runner
        self.class.runner || Runner.new
      end

      def build_argv(settings, model, transcript, plan, schema_path, thinking)
        Command.new(settings).build(
          model: self.class.model_id(model),
          resume_id: plan.resume_id,
          system_prompt: transcript.system_prompt,
          schema_path: schema_path,
          effort: self.class.effort_for(thinking)
        )
      end

      # codex reads --output-schema from a file, so the schema is written to
      # a temporary one for the length of the call.
      def with_schema_file(schema)
        return yield nil unless schema

        Tempfile.create(['ruby_llm-codex-schema-', '.json']) do |file|
          file.write(JSON.generate(Command.schema_definition(schema)))
          file.flush
          yield file.path
        end
      end

      def static_model(id)
        Model.new(
          id: id,
          name: "Codex (#{id})",
          provider: slug,
          capabilities: CAPABILITIES,
          modalities: { input: %w[text], output: %w[text] },
          metadata: { source: 'ruby_llm-providers-codex' }
        )
      end

      def reject_tools!(tools)
        return if tools.nil? || tools.empty?

        raise UnsupportedFeatureError,
              'RubyLLM tools cannot be handed to the codex CLI; the agent brings its own tools. ' \
              'Remove with_tools or choose another provider.'
      end

      def log_ignored(**options)
        ignored = options.compact.keys
        return if ignored.empty?

        RubyLLM.logger.debug { "codex: ignoring #{ignored.join(', ')} (not supported by codex exec)" }
      end
    end
  end
end

RubyLLM::Provider.register :codex, RubyLLM::Providers::Codex unless RubyLLM::Provider.resolve(:codex)
