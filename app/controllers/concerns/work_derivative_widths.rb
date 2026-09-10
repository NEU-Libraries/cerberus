# frozen_string_literal: true

# The metadata page's opt-in download sizes (small / medium / large).
#
# Everything here is a server backstop. The Stimulus controller is the primary
# enforcement, so reaching a refusal means JS-off or tampering — and in that case
# the metadata still saves and only the optional derivatives are skipped. Nothing
# here may bounce the whole form over decoration.
module WorkDerivativeWidths
  extend ActiveSupport::Concern

  private

    # Known interplay: if descriptive validation also fails, apply_descriptive
    # overwrites this flash (last writer wins). That is acceptable — valid widths
    # enqueued here are independent of the title and harmless.
    def process_derivative_widths
      raw = params[:derivative_widths]
      return unless raw.is_a?(ActionController::Parameters)

      probe = StagedImageProbe.call(work_id: params[:id])
      return flash[:alert] = 'Download sizes were skipped: no staged image was found for this work.' if probe.nil?

      enqueue_valid_widths(raw, probe)
    end

    def enqueue_valid_widths(raw, probe)
      result = DerivativeWidths.call(raw:          raw.permit(:small, :medium, :large).to_h,
                                     longest_edge: probe.longest_edge)
      unless result.valid?
        return flash[:alert] = "Download sizes were not generated: #{result.error} " \
                               'Your other changes were saved — revisit this page to configure download sizes.'
      end
      return if result.widths.empty?

      DepositDerivativesJob.perform_later(params[:id], result.widths)
    end
end
