# Leaves instance_settings the one row an instance may hold, so the next step's guard (CHECK (id = 1)) accepts the table
# (#229, from #218 ruling 3). Before the guard, two first reads at once could each insert a row, and `first` read the lowest
# id: that row is kept, with id 1, and the others, which nothing read, are removed. An instance with no row keeps none here;
# InstanceSetting.current makes it on first use. Plain SQL: a released migration must not depend on the application's models.
class NormaliseInstanceSettingsToOneRow < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM instance_settings WHERE id <> (SELECT MIN(id) FROM instance_settings)"
    execute "UPDATE instance_settings SET id = 1 WHERE id <> 1"
  end

  def down
    # The data stays: the rows removed were never read, and the guard's rollback only lifts the check.
  end
end
