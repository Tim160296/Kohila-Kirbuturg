import { db, json } from '../../lib/db.js';
export const config = { path: '/api/book' };
export default async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  let b; try { b = await req.json(); } catch { return json({ error: 'Vigane päring' }, 400); }
  const s = (v, n) => String(v ?? '').trim().slice(0, n);
  const name = s(b.name, 100), phone = s(b.phone, 30), email = s(b.email, 120), note = s(b.note, 500);
  if (!name || !phone || !/^\S+@\S+\.\S+$/.test(email)) return json({ error: 'Palun täida nimi, telefon ja korrektne e-post.' }, 400);
  if (typeof b.type !== 'string' || !/^[a-z0-9]{2,12}$/.test(b.type) || !/^\d{4}-\d{2}-\d{2}$/.test(b.start)) return json({ error: 'Vigased andmed.' }, 400);
  const { data, error } = await db.rpc('book_box', { p_name: name, p_phone: phone, p_email: email, p_type: b.type, p_start: b.start, p_note: note });
  if (error) {
    if (error.message.includes('full') || error.code === '23P01') return json({ error: 'Valitud kuupäevaks pole sellist boksi vabu. Proovi teist kuupäeva või boksi tüüpi.' }, 409);
    if (error.message.includes('bad_type')) return json({ error: 'Tundmatu boksi tüüp.' }, 400);
    if (error.message.includes('past_date')) return json({ error: 'Alguskuupäev ei saa olla minevikus.' }, 400);
    console.error(error); return json({ error: 'Serveri viga, proovi hiljem uuesti.' }, 500);
  }
  const r = data[0];
  return json({ box: r.box_number, end: r.end_date, hold_until: r.hold_until, price: r.price_eur });
};
