CREATE TABLE service_records (
  id                SERIAL PRIMARY KEY,
  bicycle_label     VARCHAR(60)   NOT NULL,
  service_date      DATE          NOT NULL,
  work_description  TEXT          NOT NULL,
  -- NUMERIC keeps money exact; the API never converts it to a float.
  cost              NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
  status            VARCHAR(30)   NOT NULL DEFAULT 'Booked in'
    CHECK (status IN ('Booked in', 'In progress', 'Waiting for parts',
                      'Ready for collection', 'Collected')),
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- The index page lists the newest services first and can filter by status.
CREATE INDEX service_records_date_idx ON service_records (service_date DESC, id DESC);
CREATE INDEX service_records_status_idx ON service_records (status);
