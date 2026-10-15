import { db } from '../../lib/db.js';
export const config = { schedule: '*/15 * * * *' };
export default async () => { await db.rpc('expire_bookings'); };
