# frozen_string_literal: true

# Pairs a personal inbox message with a durable repository-wide record, for the
# jobs that finish long after whoever started them moved on.
#
# The two halves have different audiences and different lifetimes. The message
# tells one person that their own job finished, and they dismiss it. The notice
# is what the admin dashboard reads, and it outlives that dismissal — a cascade
# or a reindex otherwise leaves no trace anywhere once the message is gone.
#
# An absent actor suppresses the message only. A cascade run from a rake task
# has nobody to tell and is still worth recording.
class CompletionNotice
  # @return [AdminNotice] the recorded notice, always.
  def self.deliver(kind:, subject:, body: nil, to_nuid: nil, subject_noid: nil, payload: {})
    notice = AdminNotice.create!(kind: kind, subject: subject, body: body, actor_nuid: to_nuid,
                                 subject_noid: subject_noid, payload: payload)
    SystemMessage.deliver(subject: subject, body: body, to_nuid: to_nuid) if to_nuid.present?
    notice
  end
end
