# encoding: UTF-8

require 'smartling'

module Rosette
  module Integrations
    module Smartling
      class SmartlingManager

        attr_reader :smartling_api_key, :smartling_project_id, :targeted_locales
        attr_reader :preapprove_translations
        attr_reader :datastore, :repo_name
        attr_accessor :use_sandbox

        alias :preapprove_translations? :preapprove_translations
        alias :use_sandbox? :use_sandbox

        def initialize(datastore, repo_name = nil, api_options = {})
          api_options.keys.each do |key|
            instance_variable_set("@#{key}", api_options[key])
          end

          @datastore = datastore
          @repo_name = repo_name
        end

        def push(commit_id, serializer_id)
          destination_filenames(commit_id).map do |destination|
            file_for_upload(commit_id, serializer_id) do |tmp_file, phrase_count|
              api.upload(tmp_file.path, destination, 'YAML', approved: preapprove_translations?)
            end
          end
        rescue => ex
          Rosette.logger.error('Caught an exception while pushing to Smartling API.')
          Rosette.logger.error("#{ex.message}\n#{ex.backtrace.join("\n")}")
          raise ex
        end

        def pull(locale)
          file_list_response = api.list(locale: locale)
          file_list = Rosette::Integrations::Smartling::SmartlingFileList.from_api_response(file_list_response)
          file_list.each do |file|
            datastore.add_or_update_commit_log_locale(file.commit_id, locale, file.translated_count)
          end
        end

        private

        def api
          @api ||= begin
            options = { apiKey: smartling_api_key, projectId: smartling_project_id }

            if use_sandbox?
              ::Smartling::File.sandbox(options)
            else
              ::Smartling::File.new(options)
            end
          end
        end

        def destination_filenames(commit_id)
          [File.join(repo_name, "#{commit_id}.yml")]
        end

        # @TODO: this will need to change if we inline phrases because
        # we might not have meta_keys anymore (this method assumes we do)
        def file_for_upload(commit_id, serializer_id)
          serializer_const = Rosette::Core::SerializerId.resolve(serializer_id)

          Tempfile.open(['rosette', serializer_const.default_extension]) do |file|
            serializer = serializer_const.new(file)
            phrases = datastore.phrases_by_commit(repo_name, commit_id)
            phrase_count = 0

            phrases.each do |phrase|
              serializer.write_key_value(phrase.index_value, phrase.key)
              phrase_count += 1
            end

            serializer.flush

            yield file, phrase_count
          end
        end

      end
    end
  end
end
