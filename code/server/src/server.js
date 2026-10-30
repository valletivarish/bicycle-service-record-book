import { app } from './app.js';
import { migrate } from './migrate.js';

const port = Number(process.env.PORT || 3000);

// Migrations are forward-only and additive, so the previous image can still
// run against the upgraded schema if a release has to be rolled back.
await migrate();
app.listen(port, () => console.log(`service book API listening on port ${port}`));
