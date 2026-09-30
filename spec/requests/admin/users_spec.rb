require "rails_helper"

RSpec.describe "User administration", type: :request do
  let!(:admin) { create(:admin, name: "Ann") }

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    it "lists users with their details, copy counts and the sign-up setting", :aggregate_failures do
      bo = create(:user, name: "Bo", email_address: "bo@example.test")
      create(:lot, account: bo.account, quantity: 3)
      get admin_users_path
      expect(response.body).to include("Users and sign-up", "Bo", "bo@example.test", "Sign-up is closed", '<td class="is-num">3</td>')
    end

    it "links to user administration from the avatar menu and the More page", :aggregate_failures do
      get collection_path
      expect(response.body[%r{<details class="c-menu".*?</details>}m]).to include(%(href="#{admin_users_path}"))
      get more_path
      expect(response.body).to include("Users and sign-up")
    end

    it "opens sign-up" do
      patch admin_sign_up_setting_path, params: { sign_up_open: "1" }
      expect(InstanceSetting.current).to be_sign_up_open
    end

    it "creates a user who can sign in, with the admin flag set explicitly", :aggregate_failures do
      post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password: "another long secret", admin: "1" } }
      expect(response).to redirect_to(admin_users_path)
      bo = User.find_by(email_address: "bo@example.test")
      expect([ bo.authenticate("another long secret").present?, bo.admin? ]).to eq([ true, true ])
    end

    it "edits a user's name and email" do
      bo = create(:user)
      patch admin_user_path(bo), params: { user: { name: "Bo B", email_address: "bo.b@example.test", password: "" } }
      expect(bo.reload.slice(:name, :email_address).values).to eq([ "Bo B", "bo.b@example.test" ])
    end

    it "sets a new password that replaces the old one and ends the user's sessions", :aggregate_failures do
      bo = create(:user)
      bo.sessions.create!
      patch admin_user_path(bo), params: { user: { name: bo.name, email_address: bo.email_address, password: "brand new password" } }
      expect(bo.reload.authenticate("correct horse battery")).to be(false)
      expect(bo.sessions).to be_empty
    end

    it "deletes another user with their lots and sessions after confirmation, leaving others alone", :aggregate_failures do
      bo = create(:user, name: "Bo")
      create(:lot, account: bo.account, quantity: 2)
      bo.sessions.create!
      kept = create(:lot, account: admin.account)
      get new_admin_user_deletion_path(bo)
      expect(response.body).to include("This permanently deletes Bo's account and all 2 copies in their collection. It can't be undone.")
      expect { delete admin_user_path(bo) }
        .to change(User, :count).by(-1).and change(Account, :count).by(-1).and change(Lot, :count).by(-1).and change(Session, :count).by(-1)
      expect(kept.reload.quantity).to eq(1)
    end

    it "refuses to delete yourself or demote the only admin", :aggregate_failures do
      delete admin_user_path(admin)
      expect(User.exists?(admin.id)).to be(true)
      expect(flash[:alert]).to eq("You can't delete your own account.")

      patch admin_user_path(admin), params: { user: { name: "Ann", email_address: admin.email_address, admin: "0" } }
      expect(admin.reload).to be_admin
      expect(response.body).to include("Collector needs at least one admin.")
    end
  end

  context "when signed in as a member" do
    before { sign_in_as(create(:user)) }

    it "returns 404 for every admin page and action", :aggregate_failures do
      [ -> { get admin_users_path }, -> { get new_admin_user_path }, -> { get edit_admin_user_path(admin) },
        -> { get new_admin_user_deletion_path(admin) }, -> { post admin_users_path, params: { user: { name: "X" } } },
        -> { patch admin_user_path(admin), params: { user: { name: "X" } } }, -> { delete admin_user_path(admin) },
        -> { patch admin_sign_up_setting_path, params: { sign_up_open: "1" } } ].each do |request|
        instance_exec(&request)
        expect(response).to have_http_status(:not_found)
      end
      expect(InstanceSetting.current).not_to be_sign_up_open
    end

    it "doesn't show the admin link" do
      get more_path
      expect(response.body).not_to include("Users and sign-up")
    end
  end
end
