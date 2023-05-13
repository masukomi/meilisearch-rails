module MeiliSearch
  module Rails
    # this class wraps an MeiliSearch::Index document ensuring all raised exceptions
    # are correctly logged or thrown depending on the `raise_on_failure` option
    class SafeIndex
      def initialize(index_uid, raise_on_failure, options)
        client = MeiliSearch::Rails.client
        raise "No primary key specified" unless options[:primary_key]
        primary_key = options[:primary_key]

        @raise_on_failure = raise_on_failure.nil? || raise_on_failure

        SafeIndex.log_or_throw(nil, @raise_on_failure) do
          client.create_index(index_uid, { primary_key: primary_key })
        end

        @index = client.index(index_uid)
      end

      ::MeiliSearch::Index.instance_methods(false).each do |m|
        define_method(m) do |*args, &block|
          if m == :update_settings
            args[0].delete(:attributesToHighlight) if args[0][:attributesToHighlight]
            args[0].delete(:attributesToCrop) if args[0][:attributesToCrop]
            args[0].delete(:cropLength) if args[0][:cropLength]
          end

          SafeIndex.log_or_throw(m, @raise_on_failure) do
            return MeiliSearch::Rails.black_hole unless MeiliSearch::Rails.active?

            @index.send(m, *args, &block)
          end
        end
      end

      # special handling of wait_for_task to handle null task_id
      def wait_for_task(task_uid)
        return if task_uid.nil? && !@raise_on_failure # ok

        SafeIndex.log_or_throw(:wait_for_task, @raise_on_failure) do
          @index.wait_for_task(task_uid)
        end
      end

      # special handling of settings to avoid raising errors on 404
      def settings(*args)
        SafeIndex.log_or_throw(:settings, @raise_on_failure) do
          @index.settings(*args)
        rescue ::MeiliSearch::ApiError => e
          return {} if e.code == 404 # not fatal

          raise e
        end
      end

      def self.log_or_throw(method, raise_on_failure, &block)
        yield
      rescue ::MeiliSearch::TimeoutError, ::MeiliSearch::ApiError => e
        raise e if raise_on_failure

        # log the error
        (::Rails.logger || Logger.new($stdout)).info("[meilisearch-rails] #{e.message}")
        # return something
        case method.to_s
        when 'search'
          # some attributes are required
          { 'hits' => [], 'hitsPerPage' => 0, 'page' => 0, 'facetDistribution' => {}, 'error' => e }
        else
          # empty answer
          { 'error' => e }
        end
      end
    end
  end
end  
