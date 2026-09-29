# /up: the stock Rails health check, plus a check that every database
# configured for this environment can be opened and written to. Any failure
# raises, and the inherited rescue_from(Exception) renders the 500 "down" page.
class HealthController < Rails::HealthController
  def show
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      check_database(db_config)
    end

    render_up
  end

  private
    # Uses the app's own pool when one exists. In development (no eager
    # loading) the Solid Cache/Queue/Cable pools only appear once their models
    # load, so a short-lived connection checks those databases instead.
    def check_database(db_config)
      pool = ActiveRecord::Base.connection_handler.connection_pool_list(:writing)
        .find { |candidate| candidate.db_config.name == db_config.name }

      if pool
        pool.with_connection { |connection| check_writable(connection) }
      else
        connection = db_config.new_connection
        begin
          check_writable(connection)
        ensure
          connection.disconnect!
        end
      end
    end

    # A read-only SQLite file still answers SELECT 1 and even BEGIN IMMEDIATE;
    # only a real write raises SQLite3::ReadOnlyException. Rewriting
    # user_version with its current value, then rolling back, is such a write
    # and leaves nothing behind.
    def check_writable(connection)
      connection.transaction(requires_new: true) do
        user_version = Integer(connection.select_value("PRAGMA user_version"))
        connection.execute("PRAGMA user_version = #{user_version}")
        raise ActiveRecord::Rollback
      end
    end
end
