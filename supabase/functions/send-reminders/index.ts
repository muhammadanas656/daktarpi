import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import admin from 'npm:firebase-admin'

// 1. Initialize Firebase outside the serve function to keep it "Warm"
const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');

// Check if there are no apps initialized yet
if (!admin.apps || admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Fetch only active appointments where reminder hasn't been sent
    const { data: appointments, error } = await supabase
      .from('appointments')
      .select(`
        id, 
        schedule_date, 
        start_time,
        doctors (full_name),
        profiles (fcm_token, utc_offset)
      `)
      .eq('reminder_sent', false)
      .in('status', ['confirmed', 'waiting']);  // FIX: Skip canceled/completed

    if (error) throw error;
    if (!appointments || appointments.length === 0) return new Response("No reminders due.");

    let sentCount = 0;
    const errors: string[] = [];

    for (const appt of appointments) {
      // 3. Time Zone Math — robust offset parsing
      const offsetStr = (appt.profiles as any)?.utc_offset || '05:00:00';
      const parts = offsetStr.replace(/^[+-]/, '').split(':');
      const sign = offsetStr.startsWith('-') ? -1 : 1;
      const hoursOffset = sign * (parseInt(parts[0]) || 0);
      
      const localNow = new Date(Date.now() + (hoursOffset * 3600000));
      const oneHourFromLocal = new Date(localNow.getTime() + (60 * 60 * 1000));
      const apptTime = new Date(`${appt.schedule_date}T${appt.start_time}`);

      // 4. Send if it's in the window
      if (apptTime >= localNow && apptTime <= oneHourFromLocal) {
        const token = (appt.profiles as any)?.fcm_token;
        if (token) {
          try {
            await admin.messaging().send({
              token: token,
              notification: {
                title: 'Upcoming Appointment',
                body: `Reminder: ${(appt.doctors as any)?.full_name} is expecting you soon.`
              }
            });
            await supabase.from('appointments').update({ reminder_sent: true }).eq('id', appt.id);
            sentCount++;
          } catch (sendError: any) {
            // FIX: Don't let one bad token kill reminders for everyone else
            const errorCode = sendError?.code || sendError?.errorInfo?.code || '';
            errors.push(`Appt ${appt.id}: ${sendError.message}`);

            // If the token is invalid/unregistered, clear it so we don't retry forever
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              await supabase
                .from('profiles')
                .update({ fcm_token: null })
                .eq('fcm_token', token);
            }

            // Still mark reminder_sent to avoid infinite retries on permanent failures
            await supabase.from('appointments').update({ reminder_sent: true }).eq('id', appt.id);
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ sent: sentCount, errors: errors.length > 0 ? errors : undefined }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (e: any) {
    return new Response(e.message, { status: 500 });
  }
})