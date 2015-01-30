# KLUDGE - have to reference the module first or the autoload monkey patch causes a crash
# http://stackoverflow.com/questions/8736451/override-a-method-inside-a-gem-from-another-gem
Blacklight::BlacklightHelperBehavior
module Blacklight::BlacklightHelperBehavior
  # REMOVE THIS when updating Blacklight
  # relevant pull/issue - https://github.com/projectblacklight/blacklight/pull/528
  # relevant patch - https://github.com/projectblacklight/blacklight/commit/aa5a40d170c6568da42881ea9279c8abbfbbb031#diff-1948ff0d97b888dc61ae381aec62dfa5
  def params_for_search(options={})
    # special keys
    # params hash to mutate
    source_params = options.delete(:params) || params
    omit_keys = options.delete(:omit_keys) || []

    # params hash we'll return
    my_params = source_params.dup.merge(options.dup)


    # remove items from our params hash that match:
    #   - a key
    #   - a key and a value
    omit_keys.each do |omit_key|
      case omit_key
      when Hash
        omit_key.each do |key, values|
          next unless my_params.has_key? key

          # make sure to dup the source key, we don't want to accidentally alter the original
          my_params[key] = my_params[key].dup

          values = [values] unless values.respond_to? :each
          values.each { |v| my_params[key].delete(v) }

          if my_params[key].empty?
            my_params.delete(key)
          end
        end

      else
        my_params.delete(omit_key)
      end
    end

    if my_params[:page] and (my_params[:per_page] != source_params[:per_page] or my_params[:sort] != source_params[:sort] )
      my_params[:page] = 1
    end

    my_params.reject! { |k,v| v.nil? }

    # removing action and controller from duplicate params so that we don't get hidden fields for them.
    my_params.delete(:action)
    my_params.delete(:controller)
    # commit is just an artifact of submit button, we don't need it, and
    # don't want it to pile up with another every time we press submit again!
    my_params.delete(:commit)

    my_params
  end
end
