# frozen_string_literal: true

# "Has the primary Blob landed yet?", for the jobs that must wait for
# ContentCreationJob without racing it as a second Blob writer.
#
# Asks about the artifact rather than about a Work flag. The alternative —
# reading in_progress — couples these jobs to whichever caller happens to
# complete the Work, and that flag means "no depositor has confirmed this
# deposit", which is a question about a human and not about the file.
#
# Matches on the stable `role` token, never the human `use` label.
module PrimaryFilePresence
  PRIMARY_ROLE = 'original_file'

  private

    def primary_file?(work_id)
      AtlasRb::Work.file_sets(work_id)
                   .flat_map { |file_set| Array(file_set['assets']) }
                   .any? { |asset| asset['role'].to_s == PRIMARY_ROLE }
    end
end
