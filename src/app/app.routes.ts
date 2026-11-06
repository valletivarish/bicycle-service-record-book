import { Routes } from '@angular/router';
import { JobSheet } from './job-sheet';
import { JobSheetForm } from './job-sheet-form';
import { RecordIndex } from './record-index';

export const routes: Routes = [
  { path: '', component: RecordIndex, title: 'Service index | Bicycle desk' },
  { path: 'records/new', component: JobSheetForm, title: 'New job sheet | Bicycle desk' },
  { path: 'records/:id', component: JobSheet, title: 'Job sheet | Bicycle desk' },
  { path: 'records/:id/edit', component: JobSheetForm, title: 'Edit job sheet | Bicycle desk' },
  { path: '**', redirectTo: '' },
];
