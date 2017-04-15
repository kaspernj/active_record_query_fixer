require "rails_helper"

describe ActiveRecordQueryFixer do
  let!(:user_1) { create :user }
  let!(:role_1) { create :role, user: user_1 }

  let!(:user_2) { create :user }
  let!(:role_2) { create :role, user: user_2 }

  describe "#fix_order_group" do
    it "fixes the missing group when ordering" do
      query = User.joins(:roles)
        .having("COUNT(roles.id) > 0")
        .order("roles.role")

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_group
        .query

      expect(query.to_a).to eq [user_1, user_2]
      expect(query.to_sql).to eq 'SELECT "users".* FROM "users" INNER JOIN "roles" ON "roles"."user_id" = "users"."id"' \
        " GROUP BY users.id, roles.role HAVING (COUNT(roles.id) > 0) ORDER BY roles.role"
    end

    it "fixes the missing select when query is distinct" do
      query = User.joins(:roles)
        .order("roles.role")
        .distinct

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_select_distinct
        .query

      expect(query.to_a).to eq [user_1, user_2]
      expect(query.to_sql).to eq 'SELECT DISTINCT roles.role, users.* FROM "users" INNER JOIN "roles" ON "roles"."user_id" = "users"."id" ORDER BY roles.role'
    end
  end
end
