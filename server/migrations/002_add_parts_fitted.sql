-- The default lets the previous release keep inserting rows during a rollback.
ALTER TABLE service_records ADD COLUMN parts_fitted VARCHAR(500) NOT NULL DEFAULT '';
