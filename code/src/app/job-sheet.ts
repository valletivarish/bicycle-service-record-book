import { CurrencyPipe, DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, input, OnInit, signal } from '@angular/core';
import { Title } from '@angular/platform-browser';
import { Router, RouterLink } from '@angular/router';
import { RecordsService } from './records.service';
import { ServiceRecord } from './service-record';

@Component({
  selector: 'app-job-sheet',
  imports: [RouterLink, DatePipe, CurrencyPipe],
  templateUrl: './job-sheet.html',
})
export class JobSheet implements OnInit {
  private service = inject(RecordsService);
  private router = inject(Router);
  private title = inject(Title);

  id = input.required<string>();
  record = signal<ServiceRecord | null>(null);
  error = signal('');
  confirmingDelete = signal(false);
  deleting = signal(false);

  ngOnInit() {
    this.service.get(Number(this.id())).subscribe({
      next: (record) => {
        this.record.set(record);
        // The tab and a printed sheet's header show which bicycle it is.
        this.title.setTitle(`Job sheet No. ${record.id} - ${record.bicycleLabel}`);
      },
      error: (err: HttpErrorResponse) =>
        this.error.set(
          err.status === 404 || err.status === 400
            ? 'This job sheet does not exist. It may have been deleted.'
            : 'The job sheet could not be loaded. Try again in a moment.',
        ),
    });
  }

  print() {
    window.print();
  }

  confirmDelete() {
    const record = this.record();
    if (!record) return;
    this.deleting.set(true);
    this.service.remove(record.id).subscribe({
      next: () => this.router.navigate(['/']),
      error: () => {
        this.deleting.set(false);
        this.confirmingDelete.set(false);
        this.error.set('The job sheet could not be deleted. Nothing was changed.');
      },
    });
  }
}
