import { CurrencyPipe, DatePipe } from '@angular/common';
import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { RecordsService } from './records.service';
import { ServiceRecord, STATUSES } from './service-record';

@Component({
  selector: 'app-record-index',
  imports: [RouterLink, FormsModule, DatePipe, CurrencyPipe],
  templateUrl: './record-index.html',
})
export class RecordIndex implements OnInit {
  private service = inject(RecordsService);

  statuses = STATUSES;
  status = '';
  search = '';
  records = signal<ServiceRecord[]>([]);
  loading = signal(true);
  error = signal('');
  // Summed in cents: costs arrive as decimal strings from PostgreSQL.
  totalCost = computed(
    () => this.records().reduce((sum, r) => sum + Math.round(Number(r.cost) * 100), 0) / 100,
  );

  ngOnInit() {
    this.load();
  }

  load() {
    this.loading.set(true);
    this.error.set('');
    this.service.list(this.status, this.search).subscribe({
      next: (rows) => {
        this.records.set(rows);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('The service records could not be loaded. Check the connection and try again.');
        this.loading.set(false);
      },
    });
  }

  clearFilters() {
    this.status = '';
    this.search = '';
    this.load();
  }

  firstLine(text: string) {
    return text.split('\n')[0];
  }
}
