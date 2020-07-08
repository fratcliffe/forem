require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  let(:user)          { create(:user) }
  let(:second_user)   { create(:user) }
  let(:super_admin)   { create(:user, :super_admin) }
  let(:pro_user)      { create(:user, :pro) }
  let(:article)       { create(:article, user: user) }
  let(:unpublished_article) { create(:article, user: user, published: false) }
  let(:organization) { create(:organization) }

  describe "GET /dashboard" do
    context "when not logged in" do
      it "redirects to /enter" do
        get "/dashboard"
        expect(response).to redirect_to("/enter")
      end
    end

    context "when logged in" do
      before do
        sign_in user
        article
      end

      it "renders user's articles" do
        get "/dashboard"
        expect(response.body).to include(CGI.escapeHTML(article.title))
      end

      it 'does not show "STATS" for articles' do
        get "/dashboard"
        expect(response.body).not_to include("Stats")
      end

      it "renders the delete button for drafts" do
        unpublished_article
        get "/dashboard"
        expect(response.body).to include "Delete"
      end

      it "renders subscriptions for articles with subscriptions" do
        user.add_role(:admin) # TODO: (Alex Smith) - update roles before release
        article_with_user_subscription_tag = create(:article, user: user, with_user_subscription_tag: true)
        create(:user_subscription,
               subscriber_id: second_user.id,
               subscriber_email: second_user.email,
               author_id: article_with_user_subscription_tag.user_id,
               user_subscription_sourceable: article_with_user_subscription_tag)

        get "/dashboard"
        expect(response.body).to include "Subscriptions"
      end

      it "renders pagination if minimum amount of posts" do
        create_list(:article, 52, user: user)
        get "/dashboard"
        expect(response.body).to include "pagination"
      end

      it "does not render pagination if less than one full page" do
        create_list(:article, 3, user: user)
        get "/dashboard"
        expect(response.body).not_to include "pagination"
      end

      it "does not render a link to pro analytics" do
        get dashboard_path

        expect(response.body).not_to include("Pro Analytics")
      end

      it "does not render a link to pro analytics for the org" do
        create(:organization_membership, type_of_user: :admin, organization: organization, user: user)

        get dashboard_path

        expect(response.body).not_to include("Pro Analytics for #{organization.name}")
      end

      it "does not render a link to upload a video" do
        get dashboard_path

        expect(response.body).not_to include("Upload a video")
      end
    end

    context "when logged in as a super admin" do
      it "renders the specified user's articles" do
        article
        user
        sign_in super_admin
        get "/dashboard/#{user.username}"
        expect(response.body).to include(CGI.escapeHTML(article.title))
      end
    end

    context "when logged in as a pro user" do
      it 'shows "STATS" for articles' do
        article = create(:article, user: pro_user)
        sign_in pro_user
        get "/dashboard"
        expect(response.body).to include("Stats")
        expect(response.body).to include("#{article.path}/stats")
      end

      it "renders a link to pro analytics" do
        sign_in pro_user
        get dashboard_path

        expect(response.body).to include("Pro Analytics")
      end

      it "renders a link to pro analytics for the org" do
        create(:organization_membership, type_of_user: :admin, organization: organization, user: pro_user)

        sign_in pro_user
        get dashboard_path

        expect(response.body).to include("Pro Analytics for #{organization.name}")
      end
    end

    context "when logged in as a non recent user" do
      it "renders a link to upload a video" do
        Timecop.freeze(Time.current) do
          user.update!(created_at: 3.weeks.ago)

          sign_in user
          get dashboard_path

          expect(response.body).to include("Upload a video")
        end
      end
    end
  end

  describe "GET /dashboard/organization" do
    let(:organization) { create(:organization) }

    context "when not logged in" do
      it "redirects to /enter" do
        get "/dashboard/organization"
        expect(response).to redirect_to("/enter")
      end
    end

    context "when logged in" do
      it "renders user's organization articles" do
        create(:organization_membership, user: user, organization: organization, type_of_user: "admin")
        article.update(organization_id: organization.id)
        sign_in user
        get "/dashboard/organization/#{organization.id}"
        expect(response.body).to include "crayons-logo"
      end

      it "does not render the delete button for other org member's drafts" do
        create(:organization_membership, user: user, organization: organization, type_of_user: "member")
        create(:organization_membership, user: second_user, organization: organization, type_of_user: "admin")
        unpublished_article.update(organization_id: organization.id)
        sign_in second_user
        get "/dashboard/organization/#{organization.id}"
        expect(response.body).not_to include("Delete")
        expect(response.body).to include(ERB::Util.html_escape(unpublished_article.title))
      end
    end
  end

  describe "GET /dashboard/following" do
    context "when not logged in" do
      it "redirects to /enter" do
        get "/dashboard/following"
        expect(response).to redirect_to("/enter")
      end
    end

    describe "followed users section" do
      before do
        sign_in user
        user.follow second_user
        user.reload
        get "/dashboard/following_users"
      end

      it "renders followed users count" do
        expect(response.body).to include "Following users (1)"
      end

      it "lists followed users" do
        expect(response.body).to include CGI.escapeHTML(second_user.name)
      end
    end

    describe "followed tags section" do
      let(:tag) { create(:tag) }

      before do
        sign_in user
        user.follow tag
        user.reload
        get "/dashboard/following_tags"
      end

      it "renders followed tags count" do
        expect(response.body).to include "Following tags (1)"
      end

      it "lists followed tags" do
        expect(response.body).to include tag.name
      end
    end

    describe "followed organizations section" do
      let(:organization) { create(:organization) }

      before do
        sign_in user
        user.follow organization
        user.reload
        get "/dashboard/following_organizations"
      end

      it "renders followed organizations count" do
        expect(response.body).to include "Following organizations (1)"
      end

      it "lists followed organizations" do
        expect(response.body).to include CGI.escapeHTML(organization.name)
      end
    end

    describe "followed podcasts section" do
      let(:podcast) { create(:podcast) }

      before do
        sign_in user
        user.follow podcast
        user.reload
        get "/dashboard/following_podcasts"
      end

      it "renders followed podcast count" do
        expect(response.body).to include "Following podcasts (1)"
      end

      it "lists followed podcasts" do
        expect(response.body).to include podcast.name
      end
    end
  end

  describe "GET /dashboard/user_followers" do
    context "when not logged in" do
      it "redirects to /enter" do
        get "/dashboard/user_followers"
        expect(response).to redirect_to("/enter")
      end
    end

    context "when logged in" do
      it "renders the current user's followers" do
        second_user.follow user
        sign_in user
        get "/dashboard/user_followers"
        expect(response.body).to include CGI.escapeHTML(second_user.name)
      end
    end
  end

  describe "GET /dashboard/pro" do
    context "when not logged in" do
      it "raises unauthorized" do
        get "/dashboard/pro"
        expect(response).to redirect_to("/enter")
      end
    end

    context "when user does not have permission" do
      it "raises unauthorized" do
        sign_in user
        expect { get "/dashboard/pro" }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when user has pro permission" do
      it "shows page properly" do
        user.add_role(:pro)
        sign_in user
        get "/dashboard/pro"
        expect(response.body).to include("pro")
      end
    end

    context "when user has pro permission and is an org admin" do
      it "shows page properly" do
        org = create :organization
        create(:organization_membership, user: user, organization: org, type_of_user: "admin")
        user.add_role(:pro)
        sign_in user
        get "/dashboard/pro/org/#{org.id}"
        expect(response.body).to include("pro")
      end
    end

    context "when user has pro permission and is an org member" do
      it "shows page properly" do
        org = create :organization
        create(:organization_membership, user: user, organization: org)
        user.add_role(:pro)
        sign_in user
        get "/dashboard/pro/org/#{org.id}"
        expect(response.body).to include("pro")
      end
    end
  end

  # TODO: (Alex Smith) - update roles before release
  describe "GET /dashboard/subscriptions" do
    before do
      sign_in user
    end

    it "renders subscriptions" do
      user.add_role(:admin)
      article_with_user_subscription_tag = create(:article, user: user, with_user_subscription_tag: true)
      user_subscription = create(:user_subscription,
                                 subscriber_id: second_user.id,
                                 subscriber_email: second_user.email,
                                 author_id: article_with_user_subscription_tag.user_id,
                                 user_subscription_sourceable: article_with_user_subscription_tag)

      get "/dashboard/subscriptions", params: { source_type: article_with_user_subscription_tag.class.name, source_id: article_with_user_subscription_tag.id }
      expect(response.body).to include(user_subscription.subscriber_email)
    end

    it "displays a message if no subscriptions are found" do
      get "/dashboard/subscriptions", params: { source_type: article.class.name, source_id: article.id }
      expect(response.body).to include("You don't have any subscribers for this")
    end

    it "raises unauthorized when trying to access a source the user doesn't own" do
      user.add_role(:admin)
      article_with_user_subscription_tag = create(:article, :with_user_subscription_tag_role_user, with_user_subscription_tag: true)
      create(:user_subscription,
             subscriber_id: second_user.id,
             subscriber_email: second_user.email,
             author_id: article_with_user_subscription_tag.user_id,
             user_subscription_sourceable: article_with_user_subscription_tag)

      expect do
        get "/dashboard/subscriptions", params: { source_type: article_with_user_subscription_tag.class.name, source_id: article_with_user_subscription_tag.id }
      end.to raise_error(Pundit::NotAuthorizedError)
    end

    it "raises an error for disallowed source_types" do
      expect do
        get "/dashboard/subscriptions", params: { source_type: "Comment", source_id: 1 }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises an error when the source can't be found" do
      expect do
        get "/dashboard/subscriptions", params: { source_type: article.class.name, source_id: article.id + 999 }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "renders pagination if minimum amount of subscriptions" do
      user.add_role(:admin)
      article_with_user_subscription_tag = create(:article, user: user, with_user_subscription_tag: true)
      create_list(:user_subscription,
                  102, # Current pagination limit is 100
                  author: user,
                  user_subscription_sourceable: article_with_user_subscription_tag)
      get "/dashboard/subscriptions", params: { source_type: article_with_user_subscription_tag.class.name, source_id: article_with_user_subscription_tag.id }
      expect(response.body).to include "pagination"
    end

    it "does not render pagination if less than one full page" do
      user.add_role(:admin)
      article_with_user_subscription_tag = create(:article, user: user, with_user_subscription_tag: true)
      create_list(:user_subscription,
                  5,
                  author: user,
                  user_subscription_sourceable: article_with_user_subscription_tag)
      get "/dashboard/subscriptions", params: { source_type: article_with_user_subscription_tag.class.name, source_id: article_with_user_subscription_tag.id }
      expect(response.body).not_to include "pagination"
    end
  end
end
