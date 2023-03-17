#  frozen_string_literal: true

#  Copyright (c) 2023, Schweizer Wanderwege. This file is part of
#  hitobito_sww and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sww.

require 'spec_helper'

RSpec.describe PersonResource, type: :resource do
  before do
    set_user(people(:root))
    allow_any_instance_of(described_class).to receive(:index_ability, &:current_ability)
    Graphiti.context[:object] = double(can?: true)
  end

  describe 'serialization' do
    let!(:person) { Fabricate(:person, birthday: Date.today, gender: 'm') }

    def serialized_attrs
      [
        :first_name,
        :last_name,
        :nickname,
        :company_name,
        :company,
        :email,
        :address,
        :zip_code,
        :town,
        :country,
        :gender,
        :birthday,
        :primary_group_id
      ]
    end

    def date_time_attrs
      [ :birthday ]
    end

    def read_restricted_attrs
      [ :gender, :birthday ]
    end

    before do
      params[:filter] = { id: { eq: person.id } }
    end

    it 'works' do
      render

      data = jsonapi_data[0]

      expect(data.attributes.symbolize_keys.keys).to match_array [:id, :jsonapi_type] + serialized_attrs

      expect(data.id).to eq(person.id)
      expect(data.jsonapi_type).to eq('people')

      (serialized_attrs - date_time_attrs).each do |attr|
        expect(data.public_send(attr)).to eq(person.public_send(attr))
      end

      date_time_attrs.each do |attr|
        expect(data.public_send(attr)).to eq(person.public_send(attr).as_json)
      end
    end

    it 'with show_details permission it includes restricted attrs' do
      set_ability { can [:index, :show_details], Person }

      render

      expect(d[0].attributes.symbolize_keys.keys).to include *read_restricted_attrs
    end

    it  'without show_details permission it does not include restricted attrs' do
      set_ability { can :index, Person }

      render

      expect(d[0].attributes.symbolize_keys.keys).not_to include *read_restricted_attrs
    end
  end

  describe 'filtering' do
    let!(:person1) { Fabricate(:person) }
    let!(:person2) { Fabricate(:person) }

    context 'by id' do
      before do
        params[:filter] = { id: { eq: person2.id } }
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([person2.id])
      end
    end

    context 'by updated_at' do
      it 'works'
    end
  end

  describe 'sorting' do
    describe 'by id' do
      let!(:person1) { Fabricate(:person) }
      let!(:person2) { Fabricate(:person) }

      context 'when ascending' do
        before do
          params[:sort] = 'id'
        end

        it 'works' do
          render
          expect(d.map(&:id)).to eq(Person.all.pluck(:id).sort)
        end
      end

      context 'when descending' do
        before do
          params[:sort] = '-id'
        end

        it 'works' do
          render
          expect(d.map(&:id)).to eq(Person.all.pluck(:id).sort.reverse)
        end
      end
    end
  end

  describe 'sideloading' do
    before { params[:filter] = { id: person.id.to_s } }
    describe 'phone_numbers' do
      let!(:person) { Fabricate(:person) }
      let!(:phone_number1) { Fabricate(:phone_number, contactable: person) }
      let!(:phone_number2) { Fabricate(:phone_number, contactable: person) }

      before { params[:include] = 'phone_numbers' }

      it 'it works' do
        render
        phone_numbers = d[0].sideload(:phone_numbers)
        expect(phone_numbers).to have(2).items
        expect(phone_numbers.map(&:id)).to match_array [phone_number1.id, phone_number2.id]
      end
    end

    describe 'social_accounts' do
      let!(:person) { Fabricate(:person) }
      let!(:social_account1) { Fabricate(:social_account, contactable: person) }
      let!(:social_account2) { Fabricate(:social_account, contactable: person) }

      before { params[:include] = 'social_accounts' }

      it 'it works' do
        render
        social_accounts = d[0].sideload(:social_accounts)
        expect(social_accounts).to have(2).items
        expect(social_accounts.map(&:id)).to match_array [social_account1.id, social_account2.id]
      end
    end

    describe 'additional_emails' do
      let!(:person) { Fabricate(:person) }
      let!(:additional_email1) { Fabricate(:additional_email, contactable: person) }
      let!(:additional_email2) { Fabricate(:additional_email, contactable: person) }

      before { params[:include] = 'additional_emails' }

      it 'it works' do
        render
        additional_emails = d[0].sideload(:additional_emails)
        expect(additional_emails).to have(2).items
        expect(additional_emails.map(&:id)).to match_array [additional_email1.id, additional_email2.id]
      end
    end

    describe 'roles' do
      let!(:role) { Fabricate(Group::BottomLayer::Member.to_s, group: groups(:bottom_layer_one)) }
      let(:person) { role.person }

      before { params[:include] = 'roles' }

      it 'it works' do
        render
        roles = d[0].sideload(:roles)
        expect(roles).to have(1).items
        expect(roles.first.id).to eq role.id
      end
    end

    describe 'primary_group' do
      let!(:person) { people(:top_leader) }

      before { params[:include] = 'primary_group' }

      it 'it works' do
        render

        primary_group_data = d[0].sideload(:primary_group)
        expect(primary_group_data.id).to eq person.primary_group_id
        expect(primary_group_data.jsonapi_type).to eq 'groups'
      end
    end

    describe 'layer_group' do
      let!(:person) { people(:bottom_member) }

      before { params[:include] = 'layer_group' }

      it 'it works' do
        render

        layer_group_data = d[0].sideload(:layer_group)
        expect(layer_group_data.id).to eq person.primary_group_id
        expect(layer_group_data.jsonapi_type).to eq 'groups'
      end

    end
  end
end
