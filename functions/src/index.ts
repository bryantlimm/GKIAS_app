// functions/src/index.ts
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
// import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ── Helper: send to a user's tokens ──────────────────────────────────────────
async function sendToUser(userId: string, title: string, body: string, data?: Record<string, string>) {
  const userDoc = await db.collection('users').doc(userId).get();
  const tokens: string[] = userDoc.data()?.fcmTokens ?? [];
  if (tokens.length === 0) return;

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title, body },
    data: data ?? {},
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
  };

  const response = await messaging.sendEachForMulticast(message);

  // Clean up invalid tokens
  const invalidTokens: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success && (
      r.error?.code === 'messaging/invalid-registration-token' ||
      r.error?.code === 'messaging/registration-token-not-registered'
    )) {
      invalidTokens.push(tokens[i]);
    }
  });
  if (invalidTokens.length > 0) {
    await db.collection('users').doc(userId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  }
}

setGlobalOptions({ region: "asia-southeast2" });

export const onAssignmentCreated = functions.firestore.onDocumentWritten(
    'service_events/{eventId}',
    async (event) => {
      const before = event.data?.before?.data();
      const after  = event.data?.after?.data();
      
      // If 'after' doesn't exist, the document was deleted. Do nothing.
      if (!after) return;

      const beforeAssignments: any[] = before?.assignments ?? [];
      const afterAssignments:  any[] = after.assignments  ?? [];

      const ministry = after.ministry ?? 'Kebaktian';
      const eventDate = (after.date as admin.firestore.Timestamp).toDate();
      const dateStr = eventDate.toLocaleDateString('id-ID', {
        weekday: 'long', day: 'numeric', month: 'long',
      });

      // ── Find newly added or updated assignments ──
      const newAssignments = afterAssignments.filter((afterA: any) => {
        if (!afterA.volunteerId) return false;

        const beforeA = beforeAssignments.find(
            (b: any) => b.volunteerId === afterA.volunteerId && b.role === afterA.role
        );

        if (!beforeA) return true;
        if (beforeA.status === 'rejected' && afterA.status !== 'rejected') return true;

        return false;
      });

      for (const assignment of newAssignments) {
        await sendToUser(
            assignment.volunteerId,
            'Jadwal Pelayanan Baru',
            `Anda ditugaskan sebagai ${assignment.role} untuk ${ministry} pada ${dateStr}.`,
            { screen: 'notifications', eventId: event.params.eventId },
        );
      }

      // ── 2. Notify admin when volunteer rejects ────────────────────────────
      for (const afterA of afterAssignments) {
        if (!afterA.volunteerId) continue;

        const beforeA = beforeAssignments.find(
            (b: any) => b.volunteerId === afterA.volunteerId && b.role === afterA.role
        );
        
        if (beforeA && beforeA.status !== 'rejected' && afterA.status === 'rejected') {
          const adminsSnap = await db.collection('users')
              .where('role', '==', 'admin').get();

          for (const adminDoc of adminsSnap.docs) {
            await sendToUser(
                adminDoc.id,
                'Jadwal Ditolak',
                `${afterA.volunteerName ?? 'Seseorang'} menolak tugas ${afterA.role} untuk ${ministry} (${dateStr}).`,
                { screen: 'adminNotifications', eventId: event.params.eventId },
            );
          }
        }
      }
    }
);

// ── 3. D-3 and D-1 reminders ─────────────────────────────────────────────────
// Runs every day at 08:00 WIB (01:00 UTC).
export const sendServiceReminders = functions.scheduler.onSchedule(
    { schedule: '0 1 * * *', timeZone: 'Asia/Jakarta' },
    async () => {
      const now = new Date();

      for (const daysAhead of [3, 1]) {
        const targetDate = new Date(now);
        targetDate.setDate(now.getDate() + daysAhead);
        targetDate.setHours(0, 0, 0, 0);
        const nextDay = new Date(targetDate);
        nextDay.setDate(targetDate.getDate() + 1);

        const snap = await db.collection('service_events')
            .where('date', '>=', admin.firestore.Timestamp.fromDate(targetDate))
            .where('date', '<',  admin.firestore.Timestamp.fromDate(nextDay))
            .where('is_finished', '==', false)
            .get();

        for (const doc of snap.docs) {
          const data = doc.data();
          const ministry = data.ministry ?? 'Kebaktian';
          const assignments: any[] = data.assignments ?? [];
          const eventDate = (data.date as admin.firestore.Timestamp).toDate();
          const dateStr = eventDate.toLocaleDateString('id-ID', {
            weekday: 'long', day: 'numeric', month: 'long',
          });

          for (const assignment of assignments) {
            if (assignment.status !== 'accepted') continue;  // only accepted volunteers

            await sendToUser(
                assignment.volunteerId,
            daysAhead === 1 ? '⏰ Besok Ada Ibadah!' : '📅 3 Hari Lagi',
            `Ingat, Anda bertugas sebagai ${assignment.role} untuk ${ministry} pada ${dateStr}.`,
            { screen: 'schedules', eventId: doc.id },
            );
          }
        }
      }
    }
);
