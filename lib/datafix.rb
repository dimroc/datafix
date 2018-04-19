require "datafixes"
require "datafix/version"
require "datafix/datafix_status"
require "datafix/datafix_status_presenter"
require "datafix/railtie" if defined?(Rails)

class Datafix
  DIRECTIONS = %w[up down]

  class << self
    def migrate(direction)
      new.migrate(direction)
    end

    def up?
      new.up?
    end

    private

    def connection
      @connection ||= ActiveRecord::Base.connection
    end

    def execute(*args)
      connection.execute(*args)
    end

    def table_exists?(table_name)
      ActiveRecord::Base.connection.table_exists? table_name
    end

    def transaction
      ActiveRecord::Base.transaction do
        yield
      end
    end

    def archive_table(table_name)
      log "Archive #{table_name} for Rollback" if self.respond_to?(:log)
      execute "CREATE TABLE archived_#{table_name} ( LIKE #{table_name} INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES )"
      execute "INSERT INTO archived_#{table_name} SELECT * FROM #{table_name}"
    end

    def revert_archive_table(table_name)
      log "Move old #{table_name} back" if self.respond_to?(:log)
      execute "TRUNCATE TABLE #{table_name}"
      execute "INSERT INTO #{table_name} SELECT * FROM archived_#{table_name}"
      execute "DROP TABLE archived_#{table_name}"
    end
  end

  attr_reader :name, :script_name
  def initialize(name=self.class.name, version=nil)
    @name = name
    @script_name = name.camelize.demodulize
    @passed_version = version
  end

  def version
    @version ||= @passed_version || fetch_version
  end

  def migrate(direction)
    raise ArgumentError unless DIRECTIONS.include?(direction)

    self.class.public_send(direction.to_sym)
    log_run(direction)
    log_status(direction)
  end

  def up?
    response = execute("SELECT * FROM datafix_statuses WHERE version = '#{version}'");
    response.first.present?
  end

  def down?
    !up?
  end

  private

  def fetch_version
    migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db", "datafixes")).migrations
    migrations.detect do |migration|
      migration.name == script_name
    end.try(:version)
  end

  def log_run(direction)
    puts "migrating #{script_name} #{direction}"

    execute(<<-SQL)
    INSERT INTO datafix_logs
    (direction, script, timestamp)
    VALUES ('#{direction}', '#{script_name}', NOW())
    SQL
  end

  def log_status(direction)
    if(direction == 'down')
      DatafixStatus.where(version: version.to_s).delete_all
    elsif(down? && direction == 'up')
      DatafixStatus.create(version: version.to_s)
    end
  end

  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def execute(*args)
    connection.execute(*args)
  end
end
