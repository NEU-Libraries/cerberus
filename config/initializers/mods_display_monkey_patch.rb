# for some very reduced or mangled versions of mods, we hit exceptions
# better to email the error than cause a crash
module ModsDisplay
  module ControllerExtension
    def render_mods_display(model)
      begin
        super
      rescue Exception => error
        ExceptionNotifier.notify_exception(error)
        return ''
      end
    end
  end
end
