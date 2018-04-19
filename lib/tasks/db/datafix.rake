namespace :db do
  desc "Run the 'up' on all unrun datafixes"
  task :datafix => :environment do
    if ENV['NAME'].present?
      Rake::Task["db:datafix:up"].invoke
    else
      migrations.each do |migration|
        if !Datafix::DatafixStatus.where(version: migration.version.to_s).any?
          require migration.filename
          klass_from_name(File.basename(migration.filename)).migrate('up')
        end
      end
    end
  end

  namespace :datafix do
    desc "Run the 'up' on the passed datafix"
    task :up => :environment do
      name = ENV['NAME']
      raise 'NAME required' if name.blank?

      require path_from_name(name)
      klass_from_name(name).migrate('up')
    end

    desc "Run the 'down' operation on the passed datafix"
    task :down => :environment do
      name = ENV['NAME']
      raise 'NAME required' if name.blank?

      require path_from_name(name)
      klass_from_name(name).migrate('down')
    end

    desc "Show the statuses of all datafixes"
    task :status => :environment do
      puts Datafix::DatafixStatusPresenter.table_header
      migrations.each do |migration|
        presenter = Datafix::DatafixStatusPresenter.from_migration(migration)
        puts presenter.to_table_s
      end
      puts
    end
  end

  private

  def migrations
    ActiveRecord::MigrationContext.new(Rails.root.join("db", "datafixes")).migrations
  end

  def script_from_name(name)
    name.split(File::SEPARATOR).last.gsub(/^\d+_/, '').gsub(/.rb$/, '').camelize
  end

  def klass_from_name(name)
    "Datafixes::#{script_from_name(name)}".constantize
  end

  def path_from_name(name)
    unless name =~ %r(^db/datafixes/)
      name = name.underscore
      name = Dir.glob("db/datafixes/*_#{name}.rb").first
    end
    Rails.root.join(name)
  end
end
