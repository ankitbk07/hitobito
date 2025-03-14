#  Copyright (c) 2012-2014, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module Paranoia
  module Globalized
    extend ActiveSupport::Concern

    include ::Globalized

    included do
      acts_as_paranoid
      extend Paranoia::RegularScope

      prepend Paranoia::Globalized::Translation
    end

    module Translation
      def really_destroy!
        super && translations.destroy_all
      end
    end

    module ClassMethods
      def list
        includes(:translations)
          .left_join_translation
          .select("#{table_name}.*", translated_label_column)
          .order("#{table_name}.deleted_at ASC NULLS FIRST, #{translated_label_column} NULLS LAST")
          .distinct
      end
    end
  end
end
