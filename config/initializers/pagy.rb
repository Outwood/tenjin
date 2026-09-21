# frozen_string_literal: true

require "pagy/extras/bootstrap"
require "pagy/extras/overflow"

# A page number past the end is a stale link or a typed URL, not an error
Pagy::DEFAULT[:overflow] = :last_page
