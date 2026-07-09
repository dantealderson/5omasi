// Khomasi Notification Worker
// Sends FCM push notifications + cron-based match validation

export default {
  // ============================================
  // HTTP Handler (for app-triggered notifications)
  // ============================================
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'POST only' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const authHeader = request.headers.get('Authorization');
    if (authHeader !== `Bearer ${env.API_KEY}`) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    try {
      const body = await request.json();
      const { tokens, title, body: msgBody, data } = body;

      if (!tokens || !tokens.length || !title || !msgBody) {
        return new Response(JSON.stringify({ error: 'Missing: tokens, title, body' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const accessToken = await getFCMAccessToken(env);
      const results = await Promise.allSettled(
        tokens.map(token => sendFCM(env.FCM_PROJECT_ID, accessToken, token, title, msgBody, data))
      );

      const sent = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.filter(r => r.status === 'rejected').length;

      return new Response(JSON.stringify({ sent, failed }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },

  // ============================================
  // CRON Handler - runs every 5 minutes
  // Checks matches starting within 1 hour
  // ============================================
  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkAndProcessMatches(env));
  },
};

// ============================================
// MATCH VALIDATION LOGIC
// ============================================

async function checkAndProcessMatches(env) {
  try {
    const firestoreToken = await getFirestoreAccessToken(env);
    const projectId = env.FCM_PROJECT_ID;

    // Get all open matches
    const openMatches = await firestoreQuery(projectId, firestoreToken, {
      structuredQuery: {
        from: [{ collectionId: 'matches' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'status' },
            op: 'EQUAL',
            value: { stringValue: 'open' },
          },
        },
      },
    });

    const now = new Date();
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);

    const fcmToken = await getFCMAccessToken(env);

    for (const doc of openMatches) {
      if (!doc.document) continue;
      const fields = doc.document.fields;
      const docPath = doc.document.name;
      const matchId = docPath.split('/').pop();

      // Parse match dateTime
      const matchDateTimeStr = fields.dateTime?.timestampValue;
      if (!matchDateTimeStr) continue;
      const matchDateTime = new Date(matchDateTimeStr);

      // Only process matches starting within the next hour
      if (matchDateTime <= now || matchDateTime > oneHourFromNow) continue;

      const currentPlayers = parseInt(fields.currentPlayers?.integerValue || '0');
      const maxPlayers = parseInt(fields.maxPlayers?.integerValue || '10');
      const refereeId = fields.refereeId?.stringValue || '';
      const stadiumName = fields.stadiumName?.stringValue || 'ملعب';

      const isFull = currentPlayers >= maxPlayers;
      const hasReferee = refereeId.length > 0;

      if (!isFull || !hasReferee) {
        // Match is NOT valid → cancel it
        let reason = '';
        if (!isFull && !hasReferee) {
          reason = 'لم يكتمل عدد اللاعبين ولا يوجد حكم';
        } else if (!isFull) {
          reason = 'لم يكتمل عدد اللاعبين';
        } else {
          reason = 'لا يوجد حكم للمباراة';
        }

        await cancelMatchWithRefund(projectId, firestoreToken, fcmToken, matchId, fields, reason, stadiumName);
      } else {
        // Match IS valid and full → send "starts in 1 hour" reminder
        const timeUntilMatch = matchDateTime.getTime() - now.getTime();
        const minutesUntil = timeUntilMatch / (60 * 1000);

        // Send reminder if match starts in 30-65 minutes (covers the 5-min cron window)
        if (minutesUntil <= 65 && minutesUntil > 30) {
          // Check if we already sent this reminder
          const reminderSent = fields.hourReminderSent?.booleanValue;
          if (!reminderSent) {
            const playerIds = collectPlayerIds(fields);
            if (playerIds.length > 0) {
              const tokens = await getFCMTokensForUsers(projectId, firestoreToken, playerIds);
              if (tokens.length > 0) {
                await sendFCMBatch(fcmToken, projectId, tokens,
                  '⏰ المباراة تبدأ قريباً!',
                  `المباراة في ${stadiumName} تبدأ خلال أقل من ساعة - استعدوا!`,
                  { matchId, type: 'match_reminder' }
                );
              }
            }
            // Mark reminder as sent
            await firestoreUpdate(projectId, firestoreToken, matchId, {
              'hourReminderSent': { booleanValue: true },
            });
          }
        }
      }
    }

    console.log('Cron check completed at', now.toISOString());
  } catch (e) {
    console.error('Cron error:', e.message);
  }
}

// Cancel match, refund tokens, send notifications
async function cancelMatchWithRefund(projectId, firestoreToken, fcmToken, matchId, fields, reason, stadiumName) {
  try {
    // Collect all players from both teams
    const teamAPlayers = fields.teamAPlayers?.arrayValue?.values || [];
    const teamBPlayers = fields.teamBPlayers?.arrayValue?.values || [];
    const allPlayers = [...teamAPlayers, ...teamBPlayers];

    // Refund each player
    for (const player of allPlayers) {
      const playerFields = player.mapValue?.fields;
      if (!playerFields) continue;

      const oderId = playerFields.oderId?.stringValue;
      const bookedByUserId = playerFields.bookedByUserId?.stringValue;
      const refundTo = bookedByUserId || oderId;

      if (refundTo) {
        await refundTokens(projectId, firestoreToken, refundTo, matchId, reason);
      }
    }

    // Update match status to cancelled
    await firestoreUpdate(projectId, firestoreToken, matchId, {
      'status': { stringValue: 'cancelled' },
      'cancelledAt': { timestampValue: new Date().toISOString() },
      'cancellationReason': { stringValue: reason },
      'autoCancel': { booleanValue: true },
    });

    // Notify all players
    const playerIds = collectPlayerIds(fields);
    if (playerIds.length > 0) {
      const tokens = await getFCMTokensForUsers(projectId, firestoreToken, playerIds);
      if (tokens.length > 0) {
        await sendFCMBatch(fcmToken, projectId, tokens,
          '❌ تم إلغاء المباراة',
          `تم إلغاء المباراة في ${stadiumName} - ${reason}. تم استرداد التوكنات.`,
          { matchId, type: 'match_cancelled' }
        );
      }
    }

    console.log(`Match ${matchId} cancelled: ${reason}`);
  } catch (e) {
    console.error(`Error cancelling match ${matchId}:`, e.message);
  }
}

// Refund 1 token to a user
async function refundTokens(projectId, firestoreToken, userId, matchId, reason) {
  try {
    // Get current token balance
    const userDoc = await firestoreGet(projectId, firestoreToken, 'users', userId);
    if (!userDoc || !userDoc.fields) return;

    const currentTokens = parseInt(userDoc.fields.matchTokens?.integerValue || '0');
    const newTokens = currentTokens + 1;

    // Update user matchTokens
    await firestoreUpdateDoc(projectId, firestoreToken, 'users', userId, {
      'matchTokens': { integerValue: String(newTokens) },
    });

    // Add transaction record to top-level tokenTransactions collection
    await firestoreAddDoc(projectId, firestoreToken, 'tokenTransactions', {
      'oderId': { stringValue: userId },
      'type': { stringValue: 'matchRefund' },
      'amount': { integerValue: '1' },
      'balanceAfter': { integerValue: String(newTokens) },
      'matchId': { stringValue: matchId },
      'description': { stringValue: `استرداد - إلغاء المباراة: ${reason}` },
      'createdAt': { timestampValue: new Date().toISOString() },
    });
  } catch (e) {
    console.error(`Error refunding user ${userId}:`, e.message);
  }
}

// Collect player IDs from match fields
function collectPlayerIds(fields) {
  const ids = [];
  const teamA = fields.teamAPlayers?.arrayValue?.values || [];
  const teamB = fields.teamBPlayers?.arrayValue?.values || [];
  for (const player of [...teamA, ...teamB]) {
    const oderId = player.mapValue?.fields?.oderId?.stringValue;
    if (oderId) ids.push(oderId);
  }
  return ids;
}

// Get FCM tokens for a list of user IDs
async function getFCMTokensForUsers(projectId, firestoreToken, userIds) {
  const tokens = [];
  for (const userId of userIds) {
    try {
      const userDoc = await firestoreGet(projectId, firestoreToken, 'users', userId);
      const fcmToken = userDoc?.fields?.fcmToken?.stringValue;
      if (fcmToken) tokens.push(fcmToken);
    } catch (_) {}
  }
  return tokens;
}

// Send FCM to multiple tokens
async function sendFCMBatch(accessToken, projectId, tokens, title, body, data) {
  await Promise.allSettled(
    tokens.map(token => sendFCM(projectId, accessToken, token, title, body, data))
  );
}

// ============================================
// FIRESTORE REST API HELPERS
// ============================================

async function getFirestoreAccessToken(env) {
  const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const jwt = await signJWT(header, payload, serviceAccount.private_key);

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error('Failed to get Firestore access token: ' + JSON.stringify(tokenData));
  }
  return tokenData.access_token;
}

async function firestoreQuery(projectId, accessToken, query) {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(query),
    }
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore query error: ${err}`);
  }
  return res.json();
}

async function firestoreGet(projectId, accessToken, collection, docId) {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${docId}`,
    {
      headers: { 'Authorization': `Bearer ${accessToken}` },
    }
  );
  if (!res.ok) return null;
  return res.json();
}

async function firestoreUpdate(projectId, accessToken, matchId, fields) {
  const updateMask = Object.keys(fields).map(f => `updateMask.fieldPaths=${f}`).join('&');
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/matches/${matchId}?${updateMask}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    }
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore update error: ${err}`);
  }
  return res.json();
}

async function firestoreUpdateDoc(projectId, accessToken, collection, docId, fields) {
  const updateMask = Object.keys(fields).map(f => `updateMask.fieldPaths=${f}`).join('&');
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${docId}?${updateMask}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    }
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore update doc error: ${err}`);
  }
}

async function firestoreAddDoc(projectId, accessToken, collectionPath, fields) {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    }
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore add doc error: ${err}`);
  }
}

// ============================================
// FCM HELPERS
// ============================================

async function getFCMAccessToken(env) {
  const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const jwt = await signJWT(header, payload, serviceAccount.private_key);

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error('Failed to get FCM access token: ' + JSON.stringify(tokenData));
  }
  return tokenData.access_token;
}

async function sendFCM(projectId, accessToken, fcmToken, title, body, data) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data: data || {},
          android: {
            priority: 'high',
            notification: {
              channel_id: 'khomasi_matches',
              sound: 'default',
            },
          },
        },
      }),
    }
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`FCM error: ${err}`);
  }
  return res.json();
}

// ============================================
// JWT SIGNING
// ============================================

async function signJWT(header, payload, privateKeyPem) {
  const enc = new TextEncoder();

  const pemContents = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '');
  const keyBuffer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(signingInput));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${signingInput}.${sigB64}`;
}
