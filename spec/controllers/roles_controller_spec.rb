#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

describe RolesController do
  before { sign_in(people(:top_leader)) }

  let(:group) { groups(:top_group) }
  let(:person) { Fabricate(:person) }
  let(:role) { Fabricate(Group::TopGroup::Member.name.to_sym, person: person, group: group, created_at: 1.year.ago) }

  describe "GET new" do
    it "sets a role of the correct type" do
      get :new, params: {group_id: group.id, role: {group_id: group.id, type: Group::TopGroup::Member.sti_name}}

      expect(assigns(:role)).to be_kind_of(Group::TopGroup::Member)
      expect(assigns(:role).group_id).to eq(group.id)
    end

    it "sets start_on to default value today" do
      get :new, params: {group_id: group.id, role: {group_id: group.id, type: Group::TopGroup::Member.sti_name}}

      expect(assigns(:role).start_on).to eq(Date.current)
    end
  end

  describe "POST create" do
    context "with privacy policies in hierarchy" do
      before do
        file = Rails.root.join("spec", "fixtures", "files", "images", "logo.png")
        image = ActiveStorage::Blob.create_and_upload!(io: File.open(file, "rb"),
          filename: "logo.png",
          content_type: "image/png").signed_id
        group.layer_group.update(privacy_policy: image)
      end

      it "creates person if privacy policy is accepted" do
        expect do
          post :create, params: {
            group_id: group.id,
            role: {group_id: group.id,
                   person_id: nil,
                   type: Group::TopGroup::Member.sti_name,
                   new_person: {first_name: "Bob",
                                last_name: "Foo",
                                privacy_policy_accepted: "1"}}
          }
        end.to change { Person.count }.by(1)
          .and change { Role.count }.by(1)

        role = assigns(:role)
        is_expected.to redirect_to(edit_group_person_path(group, role.person))

        expect(role.group_id).to eq(group.id)
        expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>Bob Foo</i> in <i>TopGroup</i> wurde erfolgreich erstellt.")
        expect(role).to be_kind_of(Group::TopGroup::Member)
        person = role.person
        expect(person.first_name).to eq("Bob")
        expect(person.privacy_policy_accepted).to be_present
      end

      it "does not create a person if privacy policy is not accepted" do
        expect do
          post :create, params: {
            group_id: group.id,
            role: {group_id: group.id,
                   person_id: nil,
                   type: Group::TopGroup::Member.sti_name,
                   new_person: {first_name: "Bob",
                                last_name: "Foo",
                                privacy_policy_accepted: "0"}}
          }
        end.to_not change { [Person.count, Role.count] }
      end
    end

    it "new role for existing person redirects to people list" do
      post :create, params: {
        group_id: group.id,
        role: {group_id: group.id,
               person_id: person.id,
               type: Group::TopGroup::Member.sti_name}
      }

      is_expected.to redirect_to(group_people_path(group))

      role = person.reload.roles.first
      expect(role.group_id).to eq(group.id)
      expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich erstellt.")
      expect(role).to be_kind_of(Group::TopGroup::Member)
    end

    it "new role for new person redirects to person edit" do
      post :create, params: {
        group_id: group.id,
        role: {group_id: group.id,
               person_id: nil,
               type: Group::TopGroup::Member.sti_name,
               new_person: {first_name: "Hans",
                            last_name: "Beispiel"}}
      }

      role = assigns(:role)
      is_expected.to redirect_to(edit_group_person_path(group, role.person))

      expect(role.group_id).to eq(group.id)
      expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>Hans Beispiel</i> in <i>TopGroup</i> wurde erfolgreich erstellt.")
      expect(role).to be_kind_of(Group::TopGroup::Member)
      person = role.person
      expect(person.first_name).to eq("Hans")
    end

    it "new role for different group redirects to groups people list" do
      g = groups(:toppers)
      post :create, params: {
        group_id: group.id,
        role: {group_id: g.id,
               person_id: person.id,
               type: Group::GlobalGroup::Member.sti_name}
      }

      is_expected.to redirect_to(group_people_path(g))

      role = person.reload.roles.first
      expect(role.group_id).to eq(g.id)
      expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>Toppers</i> wurde erfolgreich erstellt.")
      expect(role).to be_kind_of(Group::GlobalGroup::Member)
    end

    it "sets start_on nil if explicitly stated" do
      g = groups(:toppers)
      post :create, params: {
        group_id: group.id,
        role: {group_id: g.id,
               person_id: person.id,
               type: Group::GlobalGroup::Member.sti_name,
               start_on: nil}
      }

      is_expected.to redirect_to(group_people_path(g))

      role = person.reload.roles.first
      expect(role.group_id).to eq(g.id)
      expect(role.start_on).to be_nil
      expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>Toppers</i> wurde erfolgreich erstellt.")
      expect(role).to be_kind_of(Group::GlobalGroup::Member)
    end

    it "with start_at in the future creates a future role" do
      g = groups(:toppers)
      expect do
        post :create, params: {
          group_id: group.id,
          role: {
            group_id: g.id,
            start_on: Time.zone.tomorrow,
            person_id: person.id,
            type: Group::GlobalGroup::Member.sti_name
          }
        }
      end.to change { person.roles.future.count }.by(1)
      is_expected.to redirect_to(group_people_path(g))
    end

    it "without name renders form again" do
      post :create, params: {
        group_id: group.id,
        role: {group_id: group.id,
               person_id: nil,
               type: Group::TopGroup::Member.sti_name,
               new_person: {}}
      }

      is_expected.to render_template("new")

      role = assigns(:role)
      expect(role.person).to have(1).error_on(:base)
    end

    it "without type displays error" do
      post :create, params: {group_id: group.id, role: {group_id: group.id, person_id: person.id}}

      is_expected.to render_template("new")
      expect(assigns(:role)).to have(1).error_on(:type)
    end

    it "with invalid person_id displays error" do
      post :create, params: {group_id: group.id, role: {group_id: group.id, type: Group::TopGroup::Member.sti_name, person_id: -99}}

      is_expected.to render_template("new")
      expect(assigns(:role).person).to have(1).error_on(:base)
    end

    context "as group_full" do
      before { sign_in(Fabricate(Group::TopGroup::Secretary.name.to_sym, group: group).person) }

      it "new role for existing person redirects to people list" do
        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::TopGroup::Member.sti_name}
        }

        is_expected.to redirect_to(group_people_path(group))

        role = person.reload.roles.first
        expect(role.group_id).to eq(group.id)
        expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich erstellt.")
        expect(role).to be_kind_of(Group::TopGroup::Member)
      end

      it "new role for different group is not allowed" do
        g = groups(:toppers)
        expect do
          post :create, params: {
            group_id: group.id,
            role: {group_id: g.id,
                   person_id: person.id,
                   type: Group::GlobalGroup::Member.sti_name}
          }
        end.to raise_error(CanCan::AccessDenied)
      end
    end

    context "with add request" do
      before { sign_in(user) }

      let(:user) { Fabricate(Group::BottomLayer::Leader.name, group: groups(:bottom_layer_one)).person }
      let(:person) { Fabricate(Group::TopGroup::LocalSecretary.name, group: groups(:top_group)).person }
      let(:group) { groups(:bottom_group_one_one) }

      before { groups(:top_layer).update_column(:require_person_add_requests, true) }

      it "creates request" do
        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::BottomGroup::Member.sti_name}
        }

        is_expected.to redirect_to(group_people_path(group))

        expect(person.reload.roles.count).to eq(1)
        request = person.add_requests.first
        expect(request.body_id).to eq(group.id)
        expect(request.role_type).to eq(Group::BottomGroup::Member.sti_name)
        expect(flash[:alert]).to match(/versendet/)
      end

      it "creates role if person already visible" do
        Fabricate(Group::TopGroup::Member.name, group: groups(:top_group), person: user)

        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::BottomGroup::Member.sti_name}
        }
        is_expected.to redirect_to(group_people_path(group))

        expect(person.reload.roles.count).to eq(2)
        role = person.roles.last
        expect(role.group_id).to eq(group.id)
        expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>Group 11</i> wurde erfolgreich erstellt.")
      end

      it "informs about existing request" do
        Person::AddRequest::Group.create!(
          person: person,
          requester: Fabricate(:person),
          body: group,
          role_type: Group::BottomGroup::Leader.sti_name
        )

        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::BottomGroup::Member.sti_name}
        }

        is_expected.to redirect_to(group_people_path(group))
        expect(person.reload.roles.count).to eq(1)
        expect(person.add_requests.count).to eq(1)
        expect(flash[:alert]).to match(/bereits angefragt/)
      end
    end

    context "with impersonation", versioning: true do
      let(:origin_user_id) { people(:bottom_member).id }
      let(:version) { PaperTrail::Version.last }

      before { allow(controller).to receive(:session).and_return(origin_user: origin_user_id) }

      it "new role for existing person redirects to people list" do
        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::TopGroup::Member.sti_name}
        }

        expect(flash[:notice]).to eq("Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich erstellt.")
        expect(version.whodunnit).to eq origin_user_id.to_s
      end

      it "does track request id" do
        allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return("123")
        post :create, params: {
          group_id: group.id,
          role: {group_id: group.id,
                 person_id: person.id,
                 type: Group::TopGroup::Member.sti_name}
        }
        expect(version.mutation_id).to eq "request-123"
      end
    end
  end

  describe "PUT update" do
    before { role } # create it

    it "without type displays error" do
      put :update, params: {group_id: group.id, id: role.id, role: {group_id: group.id, person_id: person.id, type: ""}}

      expect(assigns(:role)).to have(1).error_on(:type)
      is_expected.to render_template("edit")
    end

    it "redirects to person after update" do
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {label: "bla", type: role.type, group_id: role.group_id}}
      end.not_to change { Role.with_inactive.count }

      expect(flash[:notice]).to eq "Rolle <i>Member (bla)</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich aktualisiert."
      expect(role.reload.label).to eq "bla"
      expect(role.type).to eq Group::TopGroup::Member.model_name
      is_expected.to redirect_to(group_person_path(group, person))
    end

    it "updates future role" do
      role.update!(start_on: Time.zone.tomorrow)
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {label: "bla", type: role.type, group_id: role.group_id}}
      end.not_to change { Role.with_inactive.count }

      expect(flash[:notice]).to eq "Rolle <i>Member (bla)</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich aktualisiert."
      expect(role.reload.label).to eq "bla"
      expect(role.type).to eq Group::TopGroup::Member.model_name
      is_expected.to redirect_to(group_person_path(group, person))
    end

    it "terminates and creates new role if type changes" do
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {type: Group::TopGroup::Leader.sti_name}}
      end.to change { Role.with_inactive.count }.by(1)
      is_expected.to redirect_to(group_person_path(group, person))
      expect(Role.with_inactive.find(role.id)).not_to be_active
      expect(flash[:notice]).to eq "Rolle <i>Member (bis #{Date.current.yesterday.strftime("%d.%m.%Y")})</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> geändert."
    end

    it "hard destroys and creates new role if type changes and role was created recently" do
      role.update_attribute(:created_at, Time.zone.yesterday)
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {type: Group::TopGroup::Leader.sti_name}}
      end.not_to change { Role.with_inactive.count }
      is_expected.to redirect_to(group_person_path(group, person))
      expect(Role.with_inactive.where(id: role.id)).not_to be_exists
      expect(flash[:notice]).to eq "Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> geändert."
    end

    it "terminates and creates new role if type and group changes" do
      group2 = groups(:toppers)
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {type: Group::GlobalGroup::Leader.sti_name, group_id: group2.id}}
      end.to change { Role.with_inactive.count }.by(1)

      person.update_attribute(:primary_group_id, group.id)

      is_expected.to redirect_to(group_person_path(group2, person))
      expect(Role.with_inactive.find(role.id)).not_to be_active
      expect(flash[:notice]).to eq "Rolle <i>Member (bis #{Date.current.yesterday.strftime("%d.%m.%Y")})</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> in <i>Toppers</i> geändert."

      # new role's group also assigned to person's primary group
      expect(person.reload.primary_group).to eq group2
    end

    it "hard destroys and creates new role if type and group changes and role was created recently" do
      role.update_attribute(:created_at, Time.zone.yesterday)
      group2 = groups(:toppers)
      expect do
        put :update, params: {group_id: group.id, id: role.id, role: {type: Group::GlobalGroup::Leader.sti_name, group_id: group2.id}}
      end.not_to change { Role.with_inactive.count }

      person.update_attribute(:primary_group_id, group.id)

      is_expected.to redirect_to(group_person_path(group2, person))
      expect(Role.with_inactive.where(id: role.id)).not_to be_exists
      expect(flash[:notice]).to eq "Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> in <i>Toppers</i> geändert."

      # new role's group also assigned to person's primary group
      expect(person.reload.primary_group).to eq group2
    end

    context "end_on in the past" do
      let(:yesterday) { Date.current.yesterday }

      it "ends role" do
        role.update!(start_on: yesterday)
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {end_on: yesterday}}
        end.to change { Role.count }.by(-1)
        expect(response).to redirect_to(person_path(person, format: :html))
        expect(flash[:notice]).to eq "Rolle <i>Member (bis #{yesterday.strftime("%d.%m.%Y")})</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich aktualisiert."
      end

      it "renders validation message if end_on is before start_on invalid" do
        expect do
          put :update,
            params: {group_id: group.id, id: role.id,
                     role: {end_on: yesterday, start_on: Date.current}}
        end.not_to(change { Role.count })
        expect(response).to render_template("edit") # with error message in form
      end
    end

    context "his own role" do
      let(:tomorrow) { Date.current.tomorrow }
      let(:role) { roles(:top_leader) }

      it "cannot set end_on on his own role" do
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {end_on: tomorrow}}
        end.not_to change { role.reload.end_on }
      end
    end

    context "multiple groups" do
      let(:group) { groups(:bottom_group_one_one) }
      let(:group2) { groups(:bottom_group_one_two) }
      let(:role) { Fabricate(Group::BottomGroup::Leader.name.to_sym, person: person, group: group) }

      it "terminates and creates new role if group changes" do
        group3 = Fabricate(Group::GlobalGroup::Leader.name.to_s, person: person, group: groups(:toppers)).group
        person.update_attribute(:primary_group_id, group3.id)
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {type: Group::BottomGroup::Leader.sti_name, group_id: group2.id}}
        end.not_to change { Role.with_inactive.count }
        is_expected.to redirect_to(group_person_path(group2, person))
        expect(Role.with_inactive.where(id: role.id)).not_to be_exists
        expect(flash[:notice]).to eq "Rolle <i>Leader</i> für <i>#{person}</i> in <i>Group 11</i> zu <i>Leader</i> in <i>Group 12</i> geändert."

        # keeps person's primary group
        expect(person.reload.primary_group).to eq group3
      end

      it "changes primary group if role changes group" do
        group3 = Fabricate(Group::GlobalGroup::Leader.name.to_s, person: person, group: groups(:toppers)).group
        person.update_attribute(:primary_group_id, group.id)
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {type: Group::GlobalGroup::Leader.sti_name, group_id: group3.id}}
        end.not_to change { Role.with_inactive.count }
        is_expected.to redirect_to(group_person_path(group3, person))
        expect(Role.with_inactive.where(id: role.id)).not_to be_exists
        expect(flash[:notice]).to eq "Rolle <i>Leader</i> für <i>#{person}</i> in <i>Group 11</i> zu <i>Leader</i> in <i>Toppers</i> geändert."

        # person's primary group is set to new group
        expect(person.reload.primary_group).to eq group3
      end
    end

    context "as group_full" do
      before { sign_in(Fabricate(Group::TopGroup::Secretary.name.to_sym, group: group).person) }

      it "terminates and creates new role if type changes" do
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {type: Group::TopGroup::Leader.sti_name}}
        end.to change { Role.with_inactive.count }.by(1)
        is_expected.to redirect_to(group_person_path(group, person))
        expect(Role.with_inactive.find(role.id)).not_to be_active
        expect(flash[:notice]).to eq "Rolle <i>Member (bis #{Date.current.yesterday.strftime("%d.%m.%Y")})</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> geändert."
      end

      it "hard destroys and creates new role if type changes and role was created recently" do
        role.update_attribute(:created_at, Time.zone.yesterday)
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {type: Group::TopGroup::Leader.sti_name}}
        end.not_to change { Role.with_inactive.count }
        is_expected.to redirect_to(group_person_path(group, person))
        expect(Role.with_inactive.where(id: role.id)).not_to be_exists
        expect(flash[:notice]).to eq "Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> zu <i>Leader</i> geändert."
      end

      it "is not allowed if group changes" do
        g = groups(:toppers)
        expect do
          put :update, params: {group_id: group.id, id: role.id, role: {type: Group::GlobalGroup::Member.sti_name, group_id: g.id}}
        end.to raise_error(CanCan::AccessDenied)
        expect(Role.with_inactive.where(id: role.id)).to be_exists
      end
    end
  end

  describe "DELETE destroy" do
    let(:notice) { "Rolle <i>Member (bis #{Date.current.yesterday.strftime("%d.%m.%Y")})</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich gelöscht." }
    let(:hard_destroy_notice) { "Rolle <i>Member</i> für <i>#{person}</i> in <i>TopGroup</i> wurde erfolgreich gelöscht." }

    it "redirects to group after hard delete" do
      role.update_attribute(:created_at, 1.day.ago)
      user = Fabricate(Group::TopGroup::LocalGuide.name.to_sym, group: group)
      sign_in(user.person)
      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:notice]).to eq hard_destroy_notice
      is_expected.to redirect_to(group_path(group))
    end

    it "redirects to person if user can still view person" do
      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:notice]).to eq notice
      is_expected.to redirect_to(person_path(person))
    end

    it "hard destroys future role" do
      role.update!(start_on: Time.zone.tomorrow)
      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:notice]).to eq hard_destroy_notice
      is_expected.to redirect_to(person_path(person))
    end

    it "sets new primary group and shows warning if more than one group is remaining" do
      group2 = groups(:bottom_layer_one)
      group3 = groups(:bottom_layer_two)
      Fabricate(Group::BottomLayer::Member.name.to_sym,
        person: person,
        group: group2)
      group3_role1 = Fabricate(Group::BottomLayer::Leader.name.to_sym,
        person: person,
        group: group3)
      group3_role1.update_attribute(:updated_at, Time.zone.today - 10.days)

      person.update_attribute(:primary_group, group)

      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:alert]).to eq "Hauptgruppe auf <i>#{group2}</i> geändert."
      is_expected.to redirect_to(person_path(person))
      expect(person.reload.primary_group).to eq group2
    end

    it "sets new primary group and does not show warning if only one group is remaining" do
      group2 = groups(:bottom_layer_one)
      Fabricate(Group::BottomLayer::Member.name.to_sym,
        person: person,
        group: group2)
      Fabricate(Group::BottomLayer::Leader.name.to_sym,
        person: person,
        group: group2)

      person.update_attribute(:primary_group, group)

      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:alert]).to be_nil
      is_expected.to redirect_to(person_path(person))
      expect(person.reload.primary_group).to eq group2
    end

    it "does not change primary group if one role is remaining in primary group" do
      group2 = groups(:bottom_layer_one)
      Fabricate(Group::TopGroup::Leader.name.to_sym,
        person: person,
        group: group)

      Fabricate(Group::BottomLayer::Member.name.to_sym,
        person: person,
        group: group2)

      person.update_attribute(:primary_group, group)

      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:alert]).to be_nil
      is_expected.to redirect_to(person_path(person))
      expect(person.reload.primary_group).to eq group
    end

    it "does not show warning if non primary group role is deleted" do
      group2 = groups(:bottom_layer_one)
      group3 = groups(:bottom_layer_two)
      Fabricate(Group::BottomLayer::Member.name.to_sym,
        person: person,
        group: group2)
      Fabricate(Group::BottomLayer::Leader.name.to_sym,
        person: person,
        group: group3)

      person.update_attribute(:primary_group, group2)

      delete :destroy, params: {group_id: group.id, id: role.id}

      expect(flash[:alert]).to be_nil
      is_expected.to redirect_to(person_path(person))
      expect(person.primary_group).to eq group2
    end

    describe "persons last primary group" do
      let(:person) { Fabricate(:person) }

      it "returns true if only one role in persons primary group" do
        group = groups(:top_group)
        role = Fabricate(Group::TopGroup::Leader.name.to_sym,
          person: person,
          group: group)
        person.update_attribute(:primary_group, group)

        expect(controller.send(:persons_last_primary_group_role?, role)).to be true
      end

      it "returns false if there is more than one role in persons primary group" do
        group = groups(:top_group)
        role = Fabricate(Group::TopGroup::Leader.name.to_sym,
          person: person,
          group: group)
        Fabricate(Group::TopGroup::Member.name.to_sym,
          person: person,
          group: group)
        person.update_attribute(:primary_group, group)

        expect(controller.send(:persons_last_primary_group_role?, role)).to be false
      end

      it "returns false if person has no primary group" do
        group = groups(:top_group)
        role = Fabricate(Group::TopGroup::Leader.name.to_sym,
          person: person,
          group: group)

        person.update_attribute(:primary_group, nil)

        expect(controller.send(:persons_last_primary_group_role?, role)).to be false
      end

      it "returns false if role does not belong to persons primary group" do
        group = groups(:bottom_group_one_one)
        group2 = groups(:top_group)
        role = Fabricate(Group::TopGroup::Leader.name.to_sym,
          person: person,
          group: group2)
        Fabricate(Group::TopGroup::Member.name.to_sym,
          person: person,
          group: group2)
        Fabricate(Group::BottomGroup::Member.name.to_sym,
          person: person,
          group: group)
        person.update_attribute(:primary_group, group)

        expect(controller.send(:persons_last_primary_group_role?, role)).to be false
      end
    end
  end

  describe "GET details" do
    it "renders template" do
      get :details, xhr: true,
        format: :js,
        params: {role: {type: Group::TopGroup::Member.sti_name},
                 group_id: group.id}

      is_expected.to render_template("details")
      expect(assigns(:type)).to eq(Group::TopGroup::Member)
    end
  end

  describe "GET role_types" do
    it "renders template" do
      get :role_types, xhr: true, params: {group_id: group.id, role: {group_id: group.id, type: Group::TopGroup::Member.sti_name}}
      is_expected.to render_template("role_types")
      expect(assigns(:group)).to eq(group)
    end

    it "returns 404 without role" do
      expect do
        get :role_types, xhr: true, params: {group_id: group.id}
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "handling return_url param" do
    it "POST create redirects to people after create" do
      post :create, params: {
        group_id: group.id,
        role: {group_id: group.id, person_id: person.id, type: Group::TopGroup::Member.sti_name},
        return_url: group_person_path(group, person)
      }
      is_expected.to redirect_to group_person_path(group, person)
    end
  end

  describe "XHR PATCH inline update" do
    before do
      role
    end

    render_views

    it "displays only roles in group after updating" do
      patch :update, xhr: true, params: {group_id: group.id, id: role.id,
                                         role: {type: role.type, group_id: group.id, label: "label"}}

      # Expect js response
      expect(response.headers["Content-Type"]).to eq "text/javascript; charset=utf-8"

      # Check types of instance variables
      expect(assigns[:group]).to be_an_instance_of GroupDecorator
      expect(assigns[:role]).to be_an_instance_of RoleDecorator

      # Check for
      expect(response).to render_template("update")
    end
  end
end
