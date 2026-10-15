import { db, json } from '../../lib/db.js';
export const config = { path: '/api/admin' };
export default async (req) => {
  if (!process.env.ADMIN_PASSWORD || req.headers.get('x-admin-key') !== process.env.ADMIN_PASSWORD) return json({ error: 'Vale parool' }, 401);
  await db.rpc('expire_bookings');
  if (req.method === 'GET') {
    const { data, error } = await db.from('bookings').select('*, boxes(number,type)').order('start_date', { ascending: false }).limit(300);
    return error ? json({ error: error.message }, 500) : json(data);
  }
  const { id, action, method } = await req.json();
  let patch;
  if (action === 'paid') patch = { status: 'makstud', pay_method: ['sularaha', 'arve'].includes(method) ? method : 'sularaha', paid_at: new Date().toISOString() };
  else if (action === 'release') patch = { status: 'tuhistatud' };
  else if (action === 'reopen') patch = { status: 'ootel', hold_until: new Date(Date.now() + 24 * 3600e3).toISOString() };
  else return json({ error: 'Tundmatu tegevus' }, 400);
  const { error } = await db.from('bookings').update(patch).eq('id', id);
  if (error) return json({ error: error.code === '23P01' ? 'Boks on vahepeal juba teisele broneeritud.' : error.message }, error.code === '23P01' ? 409 : 500);
  return json({ ok: true });
};
