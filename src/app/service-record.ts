export interface ServiceRecord {
  id: number;
  bicycleLabel: string;
  serviceDate: string;
  workDescription: string;
  partsFitted: string;
  cost: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export type ServiceRecordInput = Pick<
  ServiceRecord,
  'bicycleLabel' | 'serviceDate' | 'workDescription' | 'partsFitted' | 'cost' | 'status'
>;

// Same list and order as the CHECK constraint in the database migration.
export const STATUSES = [
  'Booked in',
  'In progress',
  'Waiting for parts',
  'Ready for collection',
  'Collected',
];
