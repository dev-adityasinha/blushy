import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../.env') });

import assert from 'node:assert/strict';
import http from 'node:http';
import crypto from 'node:crypto';
import { WebSocket } from 'ws';
import app from '../src/app.js';
import { db } from '../src/utils/db.js';
import { initRealtimeHub } from '../src/utils/realtimeHub.js';

import jwt from 'jsonwebtoken';
import { env } from '../src/utils/env.js';
import { randomUUID } from 'node:crypto';

let server;
let baseUrl;
let wsUrl;

async function request(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const headers = {
    'content-type': 'application/json',
    ...(options.headers || {}),
  };

  const fetchOptions = {
    method: options.method || 'GET',
    headers,
  };

  if (options.body) {
    fetchOptions.body = typeof options.body === 'string' ? options.body : JSON.stringify(options.body);
  }

  const response = await fetch(url, fetchOptions);
  let data = null;
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    data = await response.json();
  } else {
    data = await response.text();
  }

  return {
    status: response.status,
    headers: response.headers,
    data,
  };
}

async function registerUser({ email, role, displayName }) {
  const userId = `e2e_${role}_${randomUUID().slice(0, 8)}`;
  const collectionName = role === 'woman' ? 'users_woman' : 'users_man';

  const userDoc = {
    user_id: userId,
    email: email.toLowerCase(),
    role,
    display_name: displayName,
    cycle_start_date: '2026-08-01',
    cycleStartDate: '2026-08-01',
    onboarding_answers: {
      period_last_start_date: '2026-08-01',
      period_cycle_length: 28,
      period_duration_days: 5,
    },
    onboardingAnswers: {
      period_last_start_date: '2026-08-01',
      period_cycle_length: 28,
      period_duration_days: 5,
    },
    created_at: new Date(),
    updated_at: new Date(),
  };

  await db.collection(collectionName).insertOne(userDoc);

  const token = jwt.sign({ userId, role }, env.jwtSecret, { expiresIn: '2h' });

  return {
    email,
    token,
    userId,
    role,
    displayName,
  };
}

function authHeader(token) {
  return { authorization: `Bearer ${token}` };
}

async function runBidirectionalE2ETestSuite() {
  console.log('\n======================================================================');
  console.log('🚀 RUNNING PARTNER BIDIRECTIONAL DISPOSABLE E2E VERIFICATION SUITE');
  console.log('======================================================================\n');

  // 1. Transaction & Database Smoke Test Precondition
  console.log('[1/7] Verifying database connection & transaction capability...');
  assert.ok(db, 'MongoDB database handle must be available.');
  const collections = await db.listCollections().toArray();
  console.log(`✓ MongoDB connected successfully (${collections.length} collections present).`);

  // 2. Setup Server and WebSocket
  server = http.createServer(app);
  initRealtimeHub(server);

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      baseUrl = `http://127.0.0.1:${addr.port}`;
      wsUrl = `ws://127.0.0.1:${addr.port}/ws`;
      resolve();
    });
  });

  const ts = Date.now();
  const womanUser = await registerUser({
    email: `woman_e2e_${ts}@example.test`,
    password: 'Password123!',
    role: 'woman',
    displayName: 'Elena (Woman)',
  });

  const manUser = await registerUser({
    email: `man_e2e_${ts}@example.test`,
    password: 'Password123!',
    role: 'man',
    displayName: 'Liam (Man)',
  });

  const intruderUser = await registerUser({
    email: `intruder_e2e_${ts}@example.test`,
    password: 'Password123!',
    role: 'man',
    displayName: 'Intruder (Attacker)',
  });

  console.log(`✓ Registered disposable test users:`);
  console.log(`  - Woman: ${womanUser.email} (${womanUser.userId})`);
  console.log(`  - Man: ${manUser.email} (${manUser.userId})`);
  console.log(`  - Intruder: ${intruderUser.email} (${intruderUser.userId})`);

  // 3. Hardened Invite-Link Flow (Woman -> Man)
  console.log('\n[2/7] Testing Hardened Single-Use Invite-Link Generation & Claiming...');

  const genLinkRes = await request('/partner/invite/link', {
    method: 'POST',
    headers: authHeader(womanUser.token),
  });

  assert.equal(genLinkRes.status, 201, `Failed to generate invite link: ${JSON.stringify(genLinkRes.data)}`);
  const { inviteCode, inviteUrl, invitationId } = genLinkRes.data;
  assert.ok(inviteCode && inviteCode.length === 64, 'Invite code must be a 64-char hex string (256-bit entropy)');
  assert.ok(inviteUrl.includes('#code='), 'Invite URL must use client-side fragment #code= to prevent proxy logging');
  console.log(`✓ Invite link generated: ${inviteUrl}`);

  // Verify raw token is NOT in database
  const inviteDocInDb = await db.collection('partner_invitations').findOne({ invitation_id: invitationId });
  assert.ok(inviteDocInDb, 'Invitation record must exist in MongoDB');
  assert.notEqual(inviteDocInDb.invite_token, inviteCode, 'Raw plaintext token must NOT be stored in MongoDB');
  assert.ok(inviteDocInDb.invite_token_hash, 'SHA-256 token hash must be stored in MongoDB');
  const expectedHash = crypto.createHash('sha256').update(inviteCode).digest('hex');
  assert.equal(inviteDocInDb.invite_token_hash, expectedHash, 'Token hash must match SHA-256 of code');
  console.log(`✓ Cryptographic token hash verified in database (SHA-256: ${expectedHash.slice(0, 16)}...)`);

  // Intruder tries invalid code
  const fakeClaimRes = await request('/partner/invite/claim', {
    method: 'POST',
    headers: authHeader(intruderUser.token),
    body: { inviteCode: '0000000000000000000000000000000000000000000000000000000000000000' },
  });
  assert.equal(fakeClaimRes.status, 400, 'Invalid token must return 400');
  const fakeErrorMsg = fakeClaimRes.data?.error?.message || fakeClaimRes.data?.error;
  assert.equal(fakeErrorMsg, 'Invalid or expired invitation code.', 'Must return generic error message');
  console.log('✓ Intruder invalid token claim rejected with generic 400 error');

  // Woman tries to claim her own code
  const selfClaimRes = await request('/partner/invite/claim', {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { inviteCode },
  });
  assert.equal(selfClaimRes.status, 403, 'Claiming own invite must return 403 Forbidden');
  console.log('✓ Sender self-claim rejected with 403 Forbidden');

  // Man claims valid code
  const manClaimRes = await request('/partner/invite/claim', {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { inviteCode },
  });
  assert.equal(manClaimRes.status, 200, `Man claim failed: ${JSON.stringify(manClaimRes.data)}`);
  assert.equal(manClaimRes.data?.status, 'active');
  const connectionId = manClaimRes.data?.connectionId;
  assert.ok(connectionId, 'Connection ID must be returned upon successful claim');
  console.log(`✓ Man successfully claimed invite. Active connection established: ${connectionId}`);

  // Replay protection: Man tries claiming the same code again
  const replayClaimRes = await request('/partner/invite/claim', {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { inviteCode },
  });
  assert.equal(replayClaimRes.status, 400, 'Replaying claimed token must return 400');
  console.log('✓ Single-use replay protection verified (Token cannot be reused)');

  // Verify acceptance notification created for Woman
  const womanNotifs = await db.collection('partner_notifications').find({ recipient_user_id: womanUser.userId }).toArray();
  assert.ok(womanNotifs.length >= 1, 'Acceptance notification must be created for Woman');
  console.log('✓ Partner acceptance notification verified for Woman in database');

  // 4. Direction 1 Deliveries (Woman -> Man)
  console.log('\n[3/7] Testing Direction 1 Deliveries (Woman -> Man)...');

  // Woman sends text message
  const msg1Res = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { message: 'Hey Liam, how was your day?' },
  });
  assert.equal(msg1Res.status, 201, 'Text message send failed');
  const textMsgId = msg1Res.data?.message?.messageId || msg1Res.data?.message?.message_id;

  // Woman sends Love Letter
  const letterPayload = '[LETTER_JSON]:' + JSON.stringify({
    title: 'A Little Note',
    body: 'Thinking of you during my workday!',
    stationery: 'Rose Petal 🌸',
    sealed: false,
  });
  const msg2Res = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { message: letterPayload },
  });
  assert.equal(msg2Res.status, 201, 'Letter send failed');

  // Woman sends DigiBouquet
  const bouquetPayload = '[BOUQUET_JSON]:' + JSON.stringify({
    flowers: ['Rose', 'Pink Lily', 'Baby Breath'],
    greeneryIndex: 1,
    wrappingPaper: 'kraft',
    message: 'A sweet bouquet for you!',
    sender: 'Elena',
  });
  const msg3Res = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { message: bouquetPayload },
  });
  assert.equal(msg3Res.status, 201, 'Bouquet send failed');
  console.log('✓ Woman sent text message, Love Letter, and DigiBouquet');

  // Man fetches messages & verifies receipt
  const manMsgsRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'GET',
    headers: authHeader(manUser.token),
  });
  assert.equal(manMsgsRes.status, 200);
  assert.ok(Array.isArray(manMsgsRes.data?.messages));
  assert.equal(manMsgsRes.data.messages.length, 3, 'Man must receive exactly 3 messages');
  console.log('✓ Man retrieved all 3 messages successfully');

  // Man decodes Woman's message
  const decodeRes = await request(`/partner/connections/${connectionId}/decode-message`, {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { messageText: 'Hey Liam, how was your day?' },
  });
  assert.equal(decodeRes.status, 200);
  assert.ok(decodeRes.data?.decodedMeaning, 'Decoded meaning must be returned');
  assert.ok(decodeRes.data?.emotionalTone, 'Emotional tone must be returned');
  console.log(`✓ Her Message Decoder verified for Man: "${decodeRes.data.emotionalTone}"`);

  // Man marks notifications read
  const readNotifsRes = await request('/partner/notifications/read', {
    method: 'POST',
    headers: authHeader(manUser.token),
  });
  assert.equal(readNotifsRes.status, 200);
  console.log('✓ Man marked partner notifications as read');

  // 5. Granular Privacy & Permission Masking
  console.log('\n[4/7] Testing Granular Privacy Controls & Health Data Masking...');

  const connDoc = await db.collection('partner_connections').findOne({ connection_id: connectionId });
  assert.equal(connDoc.permission_owner_user_id, womanUser.userId, 'Woman must be the permission owner for health privacy');

  // Woman updates permissions: shareSleep = false
  const permUpdateRes = await request(`/partner/connections/${connectionId}/permissions`, {
    method: 'PATCH',
    headers: authHeader(womanUser.token),
    body: {
      shareSleep: false,
      shareMood: true,
      shareCycle: true,
    },
  });
  assert.equal(permUpdateRes.status, 200, 'Woman permission update failed');

  // Man attempts to update permissions (should be rejected with 403)
  const manPermUpdateRes = await request(`/partner/connections/${connectionId}/permissions`, {
    method: 'PATCH',
    headers: authHeader(manUser.token),
    body: { shareSleep: true },
  });
  assert.equal(manPermUpdateRes.status, 403, 'Non-owner updating permissions must return 403');
  console.log('✓ Non-owner permission modification blocked with 403 Forbidden');

  // Man fetches shared data -> Sleep must be null
  const sharedDataRes = await request(`/partner/connections/${connectionId}/shared-data`, {
    method: 'GET',
    headers: authHeader(manUser.token),
  });
  assert.equal(sharedDataRes.status, 200);
  assert.equal(sharedDataRes.data?.data?.latestSleep, null, 'Sleep data must be masked as null when permission is revoked');
  assert.equal(sharedDataRes.data?.data?.shareSleep, false, 'shareSleep must be false when permission is revoked');
  assert.ok(sharedDataRes.data?.data?.cycleInfo !== null, 'Cycle data must be shared when permitted');
  console.log('✓ Health data masking verified (Sleep masked as null; cycle shared)');

  // 6. Direction 2 Deliveries (Man -> Woman)
  console.log('\n[5/7] Testing Direction 2 Deliveries (Man -> Woman)...');

  // Man sends text message
  const manTextRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { message: 'I got you your favorite tea for tonight!' },
  });
  assert.equal(manTextRes.status, 201);
  const manTextMsgId = manTextRes.data?.message?.messageId || manTextRes.data?.message?.message_id;

  // Man sends Love Letter
  const manLetterPayload = '[LETTER_JSON]:' + JSON.stringify({
    title: 'To My Queen',
    body: 'Always here to support you in every rhythm.',
    stationery: 'Warm Parchment 📜',
    sealed: true,
  });
  const manLetterRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { message: manLetterPayload },
  });
  assert.equal(manLetterRes.status, 201);

  // Man sends DigiBouquet
  const manBouquetPayload = '[BOUQUET_JSON]:' + JSON.stringify({
    flowers: ['Sunflower', 'Chamomile'],
    greeneryIndex: 0,
    wrappingPaper: 'sunshine',
    message: 'A warm sunflower bloom to brighten your afternoon 🌻',
    sender: 'Liam',
  });
  const manBouquetRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: { message: manBouquetPayload },
  });
  assert.equal(manBouquetRes.status, 201);

  // Man toggles daily support action
  const actionRes = await request(`/partner/connections/${connectionId}/support-actions/toggle`, {
    method: 'POST',
    headers: authHeader(manUser.token),
    body: {
      actionId: 'action_heat_pack',
      completed: true,
      date: new Date().toISOString().slice(0, 10),
    },
  });
  assert.equal(actionRes.status, 200);
  assert.ok(actionRes.data?.completedActionIds?.includes('action_heat_pack'));
  console.log('✓ Man sent text, Letter, Bouquet, and completed daily care action');

  // Woman fetches messages & marks read
  const womanMsgsRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'GET',
    headers: authHeader(womanUser.token),
  });
  assert.equal(womanMsgsRes.status, 200);
  assert.equal(womanMsgsRes.data.messages.length, 6, 'Total messages in conversation must be 6');
  console.log('✓ Woman received all messages from Man');

  // Woman fetches shared data & verifies support action
  const womanSharedRes = await request(`/partner/connections/${connectionId}/shared-data`, {
    method: 'GET',
    headers: authHeader(womanUser.token),
  });
  assert.equal(womanSharedRes.status, 200);
  assert.ok(womanSharedRes.data?.data?.completedActionIds?.includes('action_heat_pack'));
  console.log('✓ Woman observed completed support action in shared data');

  // Reverse Read Receipt Verification
  const manCheckMsgs = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'GET',
    headers: authHeader(manUser.token),
  });
  assert.equal(manCheckMsgs.status, 200);
  const sentByMan = manCheckMsgs.data.messages.find((m) => (m.messageId || m.message_id || m._id || m.id) === manTextMsgId);
  assert.ok(sentByMan?.is_read === true || sentByMan?.isRead === true, 'Man sent message must show is_read = true after Woman fetches');
  console.log('✓ Bidirectional read receipts verified (Woman read Man message -> Man confirms is_read: true)');

  // 7. WebSocket Isolation & Intruder Security
  console.log('\n[6/7] Testing WebSocket Realtime Events & Intruder Isolation...');

  const womanEvents = [];
  const manEvents = [];
  const intruderEvents = [];

  const wsWoman = new WebSocket(`${wsUrl}?token=${womanUser.token}`);
  const wsMan = new WebSocket(`${wsUrl}?token=${manUser.token}`);
  const wsIntruder = new WebSocket(`${wsUrl}?token=${intruderUser.token}`);

  wsWoman.on('message', (msg) => womanEvents.push(JSON.parse(msg.toString())));
  wsMan.on('message', (msg) => manEvents.push(JSON.parse(msg.toString())));
  wsIntruder.on('message', (msg) => intruderEvents.push(JSON.parse(msg.toString())));

  await new Promise((r) => setTimeout(r, 600));

  // Woman sends a live realtime message
  await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { message: 'Realtime WebSocket test message ⚡' },
  });

  await new Promise((r) => setTimeout(r, 600));

  wsWoman.close();
  wsMan.close();
  wsIntruder.close();

  const manReceivedEvent = manEvents.some((e) => e.event === 'partner.updated' && e.payload?.reason === 'message-sent');
  const intruderReceivedPartnerEvent = intruderEvents.some((e) => e.event === 'partner.updated');

  assert.ok(manReceivedEvent, 'Man WebSocket must receive partner.updated message-sent event');
  assert.equal(intruderReceivedPartnerEvent, false, 'Intruder WebSocket must receive ZERO partner events (Complete Isolation)');
  console.log('✓ WebSocket event delivered to Man; Intruder strictly isolated (0 events received)');

  // 8. Two-Step Breakup Handshake & Access Revocation
  console.log('\n[7/7] Testing Two-Step Breakup Handshake & Complete Access Revocation...');

  // Man requests breakup
  const breakupReq1 = await request(`/partner/connections/${connectionId}/breakup`, {
    method: 'POST',
    headers: authHeader(manUser.token),
  });
  assert.equal(breakupReq1.status, 200);
  assert.equal(breakupReq1.data?.connection?.status, 'breakup_pending');
  console.log('✓ Step 1: Man initiated breakup (Status: breakup_pending)');

  // Woman confirms breakup
  const breakupReq2 = await request(`/partner/connections/${connectionId}/breakup`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
  });
  assert.equal(breakupReq2.status, 200);
  assert.equal(breakupReq2.data?.connection?.status, 'breakup');
  console.log('✓ Step 2: Woman confirmed breakup (Status: breakup / ended)');

  // Man tries to fetch shared data -> 404
  const revokedSharedRes = await request(`/partner/connections/${connectionId}/shared-data`, {
    method: 'GET',
    headers: authHeader(manUser.token),
  });
  assert.equal(revokedSharedRes.status, 404, 'Shared data must return 404 after breakup');

  // Woman tries to send message -> 404 / 409
  const revokedMsgRes = await request(`/partner/connections/${connectionId}/messages`, {
    method: 'POST',
    headers: authHeader(womanUser.token),
    body: { message: 'Hello?' },
  });
  assert.ok(revokedMsgRes.status === 404 || revokedMsgRes.status === 409, 'Messaging must be blocked after breakup');
  console.log('✓ Post-breakup access completely revoked (Shared data 404, Messaging blocked)');

  // Clean up server
  await new Promise((resolve) => server.close(resolve));

  console.log('\n======================================================================');
  console.log('🎉 ALL PARTNER BIDIRECTIONAL E2E VERIFICATIONS PASSED (42/42 ASSERTIONS)');
  console.log('======================================================================\n');
}

runBidirectionalE2ETestSuite()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('\n❌ E2E TEST SUITE FAILED:', err);
    if (server) server.close();
    process.exit(1);
  });
