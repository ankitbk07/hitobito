# encoding: utf-8

#  Copyright (c) 2012-2015, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

# == Schema Information
#
# Table name: person_add_requests
#
#  id           :integer          not null, primary key
#  person_id    :integer          not null
#  requester_id :integer          not null
#  type         :string           not null
#  body_id      :integer          not null
#  role_type    :string
#  created_at   :datetime         not null
#

class Person::AddRequest < ActiveRecord::Base

  has_paper_trail meta: { main_id: ->(r) { r.person_id },
                          main_type: Person.sti_name }

  belongs_to :person
  belongs_to :requester, class_name: 'Person'

  validates_by_schema
  validates :person_id, uniqueness: { scope: [:type, :body_id] }

  class << self
    def for_layer(layer_group)
      joins(person: :primary_group).
        where(groups: { layer_group_id: layer_group.id })
    end
  end
end
