/* =====================================================================
   ECOMFLEX — Supabase settings.
   Both values below are meant to be public. The anon key grants nothing
   on its own; the database rules decide what anyone can see or change.
   Never put a secret / service_role key in this file.

   STRIPE_PUBLISHABLE_KEY starts pk_test_ (testing) or pk_live_ (real money).
   It is public by design. Leave it empty and the card top-up box stays hidden.
   NEVER put the Stripe secret key (sk_...) here; it goes in Supabase secrets.
   ===================================================================== */
window.ECOMFLEX = {
  SUPABASE_URL: 'https://padskodcofmmrwzuszym.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhZHNrb2Rjb2ZtbXJ3enVzenltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDcxMDIsImV4cCI6MjEwNDI4MzEwMn0.LypcXjcRRLLJXqgsB0nEBRyJBn2kT8wm7S33lC74Pco',
  STRIPE_PUBLISHABLE_KEY: ''
};
