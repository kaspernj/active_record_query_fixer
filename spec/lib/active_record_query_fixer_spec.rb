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
        ' GROUP BY "users"."id", roles.role HAVING (COUNT(roles.id) > 0) ORDER BY roles.role'
    end

    it "works with orders given as an arel object" do
      query = User.joins(:roles).group(:id).order(Role.arel_table[:role]).order("roles.id")

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = query.fix

      expect(query.to_a).to eq [user_1, user_2]
    end

    it "doesnt try to group by sum" do
      query = User.group(:id).order("SuM(id)")

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_group
        .query

      expect(query).to eq [user_1, user_2]
    end

    it "doesnt try to group by count" do
      query = User.group(:id).order("CoUnT(users.id), users.id")

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_group
        .query

      expect(query).to eq [user_1, user_2]
    end

    it "doesnt try to match arel objects" do
      query = User.order(User.arel_table[:id].asc)
      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_group
        .query

      expect(query).to eq [user_1, user_2]
    end

    it "doesnt crash when joins and distinct without an order" do
      query = User.distinct.fix
      expect(query.to_sql).to eq "SELECT DISTINCT \"users\".* FROM \"users\""
    end
  end

  describe "#fix_order_select_distinct" do
    it "fixes the missing select when query is distinct" do
      query = User.joins(:roles)
        .order("roles.role")
        .distinct

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_select_distinct
        .query

      expect(query.to_a).to eq [user_1, user_2]
      expect(query.to_sql).to eq 'SELECT DISTINCT users.*, roles.role AS active_record_query_fixer_0 FROM "users" ' \
        'INNER JOIN "roles" ON "roles"."user_id" = "users"."id" ORDER BY roles.role'
    end

    it "doesnt select all columns if something else has been selected" do
      query = User.joins(:roles)
        .select("users.email")
        .order("roles.role")
        .distinct

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = ActiveRecordQueryFixer.new(query: query)
        .fix_order_select_distinct
        .query

      expect(query.to_sql).to eq 'SELECT DISTINCT users.email, roles.role AS active_record_query_fixer_0 FROM "users" ' \
        'INNER JOIN "roles" ON "roles"."user_id" = "users"."id" ORDER BY roles.role'
    end
  end

  describe "#fix_order_group?" do
    it "returns false when a distinct is present" do
      query = User.joins(:roles)
        .having("COUNT(roles.id) > 0")
        .order("roles.role")
        .distinct

      fixer = ActiveRecordQueryFixer.new(query: query)

      expect(fixer.__send__(:fix_order_group?)).to eq false
    end

    it "returns true when an order and a group is present" do
      query = User.joins(:roles).group(:id).order("roles.role")

      fixer = ActiveRecordQueryFixer.new(query: query)

      expect(fixer.__send__(:fix_order_group?)).to eq true
    end
  end

  describe "#fix_order_select_distinct?" do
    it "returns false when a distinct is present" do
      query = User.joins(:roles)
        .having("COUNT(roles.id) > 0")
        .order("roles.role")
        .distinct

      fixer = ActiveRecordQueryFixer.new(query: query)

      expect(fixer.__send__(:fix_order_select_distinct?)).to eq true
    end
  end

  describe "#fix_select_group" do
    it "groups by selected attributes if distinct" do
      query = User.select("roles.id AS role_id, users.*").joins(:roles).order(:id).group("roles.role")

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)

      query = ActiveRecordQueryFixer.new(query: query)
        .fix
        .query

      expect(query.to_a).to eq [user_1, user_2]
    end

    it "fixes queries" do
      query = User.includes(:roles).references(:roles).group(:id)

      expect { query.to_a }.to raise_error(ActiveRecord::StatementInvalid)
      expect(query.fix.to_a).to include user_1
      expect(query.fix.to_a).to include user_2
    end
  end
end
