# Holds instance_settings to one row by construction (#229, from #218 ruling 3): the primary key makes ids unique and this
# check allows only id 1, so a second row is refused by the database whatever inserts it. A CHECK on the id rather than a unique
# index on a constant column: it needs no extra column, schema.rb dumps it, and the row's identity is then fixed (InstanceSetting
# reads and makes id 1). SQLite copies the table to add a check; nothing points at instance_settings, so the copy is safe in the
# migration's transaction. The previous step leaves at most one row, with id 1; the guard is skipped when it is already there.
class AddOneRowCheckToInstanceSettings < ActiveRecord::Migration[8.1]
  def up
    add_check_constraint :instance_settings, "id = 1", name: "instance_settings_one_row" unless check_constraint_exists?(:instance_settings, name: "instance_settings_one_row")
  end

  def down
    remove_check_constraint :instance_settings, name: "instance_settings_one_row" if check_constraint_exists?(:instance_settings, name: "instance_settings_one_row")
  end
end
