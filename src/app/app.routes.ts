import { Routes } from '@angular/router';
import { JobSheet } from './job-sheet';
import { JobSheetForm } from './job-sheet-form';
import { RecordIndex } from './record-index';

export const routes: Routes = [
  { path: '', component: RecordIndex, title: 'Service index' },
  { path: 'records/new', component: JobSheetForm, title: 'New job sheet' },
  { path: 'records/:id', component: JobSheet, title: 'Job sheet' },
  { path: 'records/:id/edit', component: JobSheetForm, title: 'Edit job sheet' },
  { path: '**', redirectTo: '' },
];
