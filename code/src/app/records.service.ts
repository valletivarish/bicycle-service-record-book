import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { ServiceRecord, ServiceRecordInput } from './service-record';

// Relative URL on purpose: in every environment the API is served from the
// same origin under /api/, proxied by the Nginx web container.
const API = '/api/records';

@Injectable({ providedIn: 'root' })
export class RecordsService {
  private http = inject(HttpClient);

  list(status: string, search: string) {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (search.trim()) params = params.set('q', search.trim());
    return this.http.get<ServiceRecord[]>(API, { params });
  }

  get(id: number) {
    return this.http.get<ServiceRecord>(`${API}/${id}`);
  }

  create(record: ServiceRecordInput) {
    return this.http.post<ServiceRecord>(API, record);
  }

  update(id: number, record: ServiceRecordInput) {
    return this.http.put<ServiceRecord>(`${API}/${id}`, record);
  }

  remove(id: number) {
    return this.http.delete<void>(`${API}/${id}`);
  }
}
