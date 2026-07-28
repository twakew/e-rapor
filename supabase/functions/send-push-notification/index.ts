import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')

serve(async (req) => {
  try {
    const payload = await req.json()
    const { user_id, title, message } = payload

    const includeStaff = payload.data?.include_staff === true;
    const onlyAdmin = payload.data?.only_admin === true;
    const isBroadcast = payload.data?.is_broadcast === true;

    const notifications = []

    // 1. BROADCAST: Kirim ke SEMUA orang yang install aplikasi
    if (isBroadcast) {
      notifications.push(
        fetch("https://onesignal.com/api/v1/notifications", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
          },
          body: JSON.stringify({
            app_id: ONESIGNAL_APP_ID,
            headings: { en: title },
            contents: { en: message },
            included_segments: ["Total Subscriptions"],
          }),
        })
      )
    } else {
      // 2. PERSONAL: Kirim ke User berdasarkan External ID (Supabase UID / NIS)
      if (user_id) {
        notifications.push(
          fetch("https://onesignal.com/api/v1/notifications", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
            },
            body: JSON.stringify({
              app_id: ONESIGNAL_APP_ID,
              include_external_user_ids: [user_id.toString()],
              // Tambahkan alias untuk kompatibilitas versi OneSignal terbaru
              include_aliases: {
                "external_id": [user_id.toString()]
              },
              target_channel: "push",
              headings: { en: title },
              contents: { en: message },
              // Masukkan data tambahan (seperti screen tujuan)
              data: payload.data,
              collapse_id: `user_notif_${user_id}`,
            }),
          })
        )
      }

      // 3. ADMIN ONLY: Khusus untuk urusan verifikasi/sistem
      if (onlyAdmin) {
        notifications.push(
          fetch("https://onesignal.com/api/v1/notifications", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
            },
            body: JSON.stringify({
              app_id: ONESIGNAL_APP_ID,
              headings: { en: title },
              contents: { en: message },
              filters: [
                { field: "tag", key: "role", relation: "=", value: "admin" }
              ]
            }),
          })
        )
      }
      // 4. STAFF (Admin & Guru): Untuk pengumuman sekolah
      else if (includeStaff) {
        notifications.push(
          fetch("https://onesignal.com/api/v1/notifications", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
            },
            body: JSON.stringify({
              app_id: ONESIGNAL_APP_ID,
              headings: { en: title },
              contents: { en: message },
              collapse_id: `staff_notif_general`,
              filters: [
                { field: "tag", key: "role", relation: "=", value: "admin" },
                { operator: "OR" },
                { field: "tag", key: "role", relation: "=", value: "guru" }
              ]
            }),
          })
        )
      }
    }

    const results = await Promise.all(notifications)

    for (const res of results) {
      if (!res.ok) {
        const errorText = await res.text()
        console.error("OneSignal API Error:", errorText)
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    })
  }
})
