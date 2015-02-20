# encoding: UTF-8

require 'thread'
require 'concurrent'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingCompleter

        DEFAULT_THREAD_POOL_SIZE = 10

        attr_reader :rosette_config, :repo_config
        attr_reader :thread_pool_size
        attr_reader :logger

        def initialize(rosette_config)
          @rosette_config = rosette_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
          @logger = Rosette.logger
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def set_thread_pool_size(size)
          @thread_pool_size = size
          self
        end

        def set_logger(logger)
          @logger = logger
          self
        end

        def complete
          build_completion_maps.each do |file_uri, locales_map|
            update_logs(locales_map)
            if all_locales_are_complete?(locales_map)
              begin
                file = locales_map[repo_config.locales.first.code]
                logger.info("Deleting file #{file_uri} from Smartling")
                delete_file(file)
                logger.info("Done deleting file #{file_uri} from Smartling")
              rescue => e
                rosette_config.error_reporter.report_error(e, {
                  file_uri: file_uri, locales_map: locales_map
                })
              end
            end
          end
        end

        private

        def delete_file(file)
          Retrier.retry(times: 3) do
            smartling_api.delete(file.file_uri)
          end.on_error(Exception).execute
        end

        def update_logs(locales_map)
          status = if all_locales_are_complete?(locales_map)
            Rosette::DataStores::PhraseStatus::TRANSLATED
          else
            Rosette::DataStores::PhraseStatus::PENDING
          end

          commit_id = derive_commit_id_from(locales_map)

          if commit_id
            rosette_config.datastore.add_or_update_commit_log(
              repo_config.name, commit_id, nil, status
            )

            update_locale_logs(locales_map)
          end
        end

        def derive_commit_id_from(locales_map)
          repo_config.locales.each do |locale|
            if file = locales_map[locale.code]
              return file.commit_id
            end
          end
        end

        def update_locale_logs(locales_map)
          locales_map.each_pair do |locale, file|
            rosette_config.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )
          end
        end

        def all_locales_are_complete?(locales_map)
          locales_map.all? { |_, v| v.complete? }
        end

        def build_completion_maps
          if thread_pool_size > 0
            build_completion_maps_asynchronously
          else
            build_completion_maps_synchronously
          end
        end

        def build_completion_maps_synchronously
          {}.tap do |completion_map|
            repo_config.locales.each do |locale|
              cur_map = build_completion_map_for(locale)
              merge_completion_maps!(completion_map, cur_map)
            end
          end
        end

        def build_completion_maps_asynchronously
          completion_map = {}
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          merge_mutex = Mutex.new

          repo_config.locales.each do |locale|
            pool << Proc.new do
              cur_map = build_completion_map_for(locale)

              merge_mutex.synchronize do
                merge_completion_maps!(completion_map, cur_map)
              end
            end
          end

          drain_pool(pool, repo_config.locales.size)
          completion_map
        end

        def drain_pool(pool, total)
          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              logger.info("#{current_completed_count} of #{total} completed")
            end

            last_completed_count = current_completed_count
          end
        end

        def merge_completion_maps!(parent_map, child_map)
          if parent_map.size == 0
            parent_map.replace(child_map)
          else
            parent_map.each_pair do |parent_file_uri, parent_locales|
              if child_map.include?(parent_file_uri)
                parent_locales.merge!(child_map[parent_file_uri])
              end
            end
          end
        end

        def build_completion_map_for(locale)
          each_file_for(locale).each_with_object({}) do |file, map|
            map[file.file_uri] = { locale.code => file }
          end
        end

        def each_file_for(locale, &block)
          locale_code = locale.code

          if block_given?
            counter = 0
            list = get_file_list(locale_code, counter)

            while list.size > 0
              list.each do |file|
                yield(file) if file.repo_name == repo_config.name
              end

              logger.info("Grabbing file list for locale #{locale_code} with offset #{counter}")
              list = get_file_list(locale_code, counter + 1)
              logger.info("Done grabbing file list for locale #{locale_code} with offset #{counter}")
              counter += list.size + 1
            end
          else
            to_enum(__method__, locale)
          end
        end

        def get_file_list(locale, offset, limit = 100)
          Retrier.retry(times: 3) do
            SmartlingFile.list_from_api_response(
              smartling_api.list(
                locale: locale, offset: offset, limit: limit
              )
            )
          end.on_error(RestClient::RequestTimeout).execute
        end

        def integration_config
          @integration_config ||=
            repo_config.get_integration('smartling')
        end

        def smartling_api
          @smartling_api ||= integration_config.smartling_api
        end

      end
    end
  end
end
