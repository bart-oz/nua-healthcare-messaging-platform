# frozen_string_literal: true

# This migration comes from solid_observer (originally 20260602000001)
class AddComponentToSolidObserverStorageInfos < ActiveRecord::Migration[8.0]
  def change
    add_column :solid_observer_storage_info, :component, :string, null: false, default: "queue_observer"
    add_index :solid_observer_storage_info, :component
  end
end
