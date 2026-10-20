class CreateImportRuns < ActiveRecord::Migration[8.1]
  def change
    # One row per import execution: an audit trail and the source for an "imports" report
    create_table :import_runs do |t|
      t.string :status, null: false, default: "running"
      t.integer :years, array: true, null: false, default: []
      t.integer :records_count, null: false, default: 0
      t.string :error_class
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end

    add_check_constraint :import_runs, "status IN ('running', 'succeeded', 'failed')",
                         name: "import_runs_status_values"
  end
end
