import { Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink],
  template: `
    <header class="masthead">
      <a routerLink="/" class="book-title">Service Record Book</a>
      <span class="book-subtitle">Bicycle repair desk</span>
    </header>
    <main class="page">
      <router-outlet />
    </main>
  `,
})
export class App {}
