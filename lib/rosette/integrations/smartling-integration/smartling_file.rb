# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingFile

        attr_reader :repo_name, :commit_id, :phrase_count, :translated_count, :file_uri

        def initialize(repo_name, commit_id, phrase_count, translated_count, file_uri)
          @repo_name = repo_name
          @commit_id = commit_id
          @phrase_count = phrase_count
          @translated_count = translated_count
          @file_uri = file_uri
        end

        def self.from_api_response(response)
          file_uri = response['fileUri']
          repo_name = File.dirname(File.dirname(file_uri))
          commit_id = File.basename(file_uri).chomp(File.extname(file_uri))
          phrase_count = response['stringCount']
          translated_count = response['completedStringCount']

          new(repo_name, commit_id, phrase_count, translated_count, file_uri)
        end

        def self.list_from_api_response(response)
          response['fileList'].map do |file|
            from_api_response(file)
          end
        end

        def complete?
          phrase_count == translated_count
        end

      end
    end
  end
end
