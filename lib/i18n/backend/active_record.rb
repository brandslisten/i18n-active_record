require 'i18n/backend/base'
require 'i18n/backend/active_record/translation'

module I18n
  module Backend
    class ActiveRecord
      autoload :Missing,     'i18n/backend/active_record/missing'
      autoload :StoreProcs,  'i18n/backend/active_record/store_procs'
      autoload :Translation, 'i18n/backend/active_record/translation'

      module Implementation
        include Base, Flatten

        def available_locales
          begin
            Translation.available_locales
          rescue ::ActiveRecord::StatementInvalid
            []
          end
        end

        def store_translations(locale, data, options = {})
          escape = options.fetch(:escape, true)
          flatten_translations(locale, data, escape, false).each do |key, value|
            Translation.locale(locale).lookup(expand_keys(key)).delete_all
            Translation.create(:locale => locale.to_s, :key => key.to_s, :value => value)
          end
        end

      protected

        def lookup(locale, key, scope = [], options = {})
          key = normalize_flat_keys(locale, key, scope, options[:separator])
          result = Translation.locale(locale).lookup(key)

          if result.empty?
            nil
          elsif result.first.key == key
            result.first.value
          else
            chop_range = if(key != '.')
              (key.size + FLATTEN_SEPARATOR.size)..-1
            else
              # Do not chop any string off of in the case of a '.', when we
              # return all translations
              0..-1
            end
            result = result.inject({}) do |hash, r|
              # Return a nested hash so that its compatible with the results of
              # SimpleBackend
              hash = hash.deep_merge(
                r.key.slice(chop_range)
                  .split(FLATTEN_SEPARATOR)
                  .reverse
                  .reduce(r.value) do |nested_key_hash, split_key|
                    {"#{split_key}": nested_key_hash}
                  end
              )
              # hash[r.key.slice(chop_range)] = r.value
              hash
            end
            result.deep_symbolize_keys
          end
        end

        # For a key :'foo.bar.baz' return ['foo', 'foo.bar', 'foo.bar.baz']
        def expand_keys(key)
          key.to_s.split(FLATTEN_SEPARATOR).inject([]) do |keys, key|
            keys << [keys.last, key].compact.join(FLATTEN_SEPARATOR)
          end
        end
      end

      include Implementation
    end
  end
end

