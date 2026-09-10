# frozen_string_literal: true

# `change`'s negated form cannot be chained inside a compound `.and(...)`
# expectation, which is exactly what the notice producers need: one action
# writes an AdminNotice and deliberately writes no Message.
RSpec::Matchers.define_negated_matcher :not_change, :change
