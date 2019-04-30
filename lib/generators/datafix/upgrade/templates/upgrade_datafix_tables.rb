class UpgradeDatafixTables < ActiveRecord::Migration
  def self.up
    create_table :datafix_statuses do |t|
      t.string :version
    end

    add_index :datafix_statuses, :version, unique: true
    rename_table :datafix_log, :datafix_logs

    datafixes = ActiveRecord::MigrationContext.new(Rails.root.join("db", "datafixes")).migrations
    datafixes.each_slice(1000) do |batch|
      execute("INSERT INTO datafix_statuses (version) VALUES #{to_sql(batch)}")
    end
  end

  def self.down
    drop_table :datafix_statuses
    rename_table :datafix_logs, :datafix_log
  end

  private

  def to_sql(datafixes)
    datafixes.map do |datafix|
      "(#{datafix.version})"
    end.join(",")
  end
end

