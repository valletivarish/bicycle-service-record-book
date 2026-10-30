import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, input, OnInit, signal } from '@angular/core';
import {
  AbstractControl,
  FormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { RecordsService } from './records.service';
import { ServiceRecordInput, STATUSES } from './service-record';

// Matches the server rule: the desk works on Irish dates, so "today" is the
// Dublin calendar day even if the browser is set to another timezone.
function todayInDublin() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Dublin' }).format(new Date());
}

function notInFuture(control: AbstractControl): ValidationErrors | null {
  return control.value && control.value > todayInDublin() ? { future: true } : null;
}

@Component({
  selector: 'app-job-sheet-form',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './job-sheet-form.html',
})
export class JobSheetForm implements OnInit {
  private service = inject(RecordsService);
  private router = inject(Router);
  private fb = inject(FormBuilder);

  id = input<string>();
  statuses = STATUSES;
  today = todayInDublin();
  saving = signal(false);
  loadError = signal('');
  saveError = signal('');
  serverErrors = signal<Record<string, string>>({});

  form = this.fb.nonNullable.group({
    bicycleLabel: ['', [Validators.required, Validators.maxLength(60)]],
    serviceDate: [this.today, [Validators.required, notInFuture]],
    status: ['Booked in', Validators.required],
    workDescription: ['', [Validators.required, Validators.maxLength(2000)]],
    partsFitted: ['', Validators.maxLength(500)],
    cost: ['0.00', [Validators.required, Validators.pattern(/^\d{1,6}(\.\d{1,2})?$/)]],
  });

  ngOnInit() {
    const id = this.id();
    if (!id) return;
    this.service.get(Number(id)).subscribe({
      next: (r) =>
        this.form.setValue({
          bicycleLabel: r.bicycleLabel,
          serviceDate: r.serviceDate,
          status: r.status,
          workDescription: r.workDescription,
          partsFitted: r.partsFitted,
          cost: r.cost,
        }),
      error: () => this.loadError.set('This job sheet could not be loaded for editing.'),
    });
  }

  showError(field: string) {
    const control = this.form.get(field);
    return (control?.invalid && control.touched) || !!this.serverErrors()[field];
  }

  save() {
    this.serverErrors.set({});
    this.saveError.set('');
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const values: ServiceRecordInput = this.form.getRawValue();
    const id = this.id();
    const request = id ? this.service.update(Number(id), values) : this.service.create(values);
    this.saving.set(true);
    request.subscribe({
      next: (saved) => this.router.navigate(['/records', saved.id]),
      error: (err: HttpErrorResponse) => {
        this.saving.set(false);
        // 422 carries one message per field; show them next to the inputs.
        if (err.status === 422 && err.error?.errors) this.serverErrors.set(err.error.errors);
        else this.saveError.set('The job sheet was not saved. Check the connection and try again.');
      },
    });
  }
}
