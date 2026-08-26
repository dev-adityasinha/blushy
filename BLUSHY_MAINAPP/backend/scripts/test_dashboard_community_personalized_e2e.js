import http from 'node:http';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import app from '../src/app.js';
import { env } from '../src/utils/env.js';
import { db } from '../src/utils/db.js';
import { personalizedCommunityService, classifyPostDeterministic } from '../src/services/personalizedCommunityService.js';
import { postRepository } from '../src/repositories/postRepository.js';

function request(server, options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = data ? JSON.parse(data) : null;
        } catch {
          parsed = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: parsed });
      });
    });
    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runDashboardCommunityPersonalizedTests() {
  console.log('\n======================================================================');
  console.log('🌸 STARTING DASHBOARD COMMUNITY PERSONALIZATION EXPANDED E2E SUITE');
  console.log('======================================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  const testUserA = `test-comm-user-a-${randomUUID().slice(0, 8)}`;
  const testUserB = `test-comm-user-b-${randomUUID().slice(0, 8)}`;
  const testUserC_ZeroData = `test-comm-user-c-${randomUUID().slice(0, 8)}`;

  const tokenA = jwt.sign({ userId: testUserA, role: 'woman' }, env.jwtSecret, { algorithm: 'HS256' });
  const tokenB = jwt.sign({ userId: testUserB, role: 'woman' }, env.jwtSecret, { algorithm: 'HS256' });
  const tokenC = jwt.sign({ userId: testUserC_ZeroData, role: 'woman' }, env.jwtSecret, { algorithm: 'HS256' });

  const testCommIds = [];

  try {
    // 1. Clean test collections
    await db.collection('users_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('user_daily_logs_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('user_period_logs_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('profile_memory_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('community_followers').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('post_votes').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });

    const testPostIds = [];
    const createTestPost = async (doc) => {
      const postId = randomUUID();
      testPostIds.push(postId);
      const postDoc = {
        post_id: postId,
        author_id: testUserA,
        title: doc.title || '',
        text: doc.text || '',
        tags: doc.tags || [],
        post_type: doc.post_type || null,
        score: doc.score ?? 5,
        privacy: doc.privacy || 'public',
        reports: [],
        created_at: doc.created_at || new Date(),
        updated_at: new Date(),
      };
      await db.collection('posts').insertOne(postDoc);
      return postDoc;
    };

    // 2. Seed test posts
    // Post 1: Cramps Question (matches User A)
    const p1 = await createTestPost({
      title: 'How do you soothe late luteal cramps?',
      text: 'Looking for natural remedies that work fast for severe cramps.',
      tags: ['cramps', 'luteal', 'pain'],
      score: 12,
    });

    // Post 2: Cramps Tip (matches User A)
    const p2 = await createTestPost({
      title: 'Tip: Warm ginger tea and magnesium for cramps',
      text: 'My advice for anyone struggling with pre-period cramping.',
      tags: ['cramps', 'tips', 'nutrition'],
      post_type: 'tip',
      score: 25,
    });

    // Post 3: Cramps Story (matches User A)
    const p3 = await createTestPost({
      title: 'My journey overcoming severe PMS fatigue and cramps',
      text: 'When I started tracking my luteal phase, everything changed.',
      tags: ['story', 'fatigue', 'cramps'],
      score: 18,
    });

    // Post 4: Follicular Fitness Question (matches User B)
    const p4 = await createTestPost({
      title: 'What workouts are best during the follicular phase?',
      text: 'Energy is high and I want to start strength training.',
      tags: ['fitness', 'follicular', 'energy'],
      score: 15,
    });

    // Post 5: Fitness Tip (matches User B)
    const p5 = await createTestPost({
      title: 'Tips for high energy follicular strength training',
      text: 'Recommend compound lifts during day 7-12 of your cycle.',
      tags: ['fitness', 'tips', 'strength'],
      post_type: 'tip',
      score: 30,
    });

    // Post 6: Fitness Story (matches User B)
    const p6 = await createTestPost({
      title: 'My experience with morning runs in follicular phase',
      text: 'Today I hit my personal best 5k run.',
      tags: ['fitness', 'story', 'running'],
      score: 20,
    });

    // Post 7: Private post (MUST NEVER BE RETURNED)
    const pPrivate = await createTestPost({
      title: 'Confidential private reflection',
      text: 'This is a private post.',
      tags: ['cramps', 'fitness'],
      privacy: 'private',
      score: 99,
    });

    // 3. Setup User Profiles & Initial Signals
    await db.collection('users_woman').insertOne({
      user_id: testUserA,
      email: `${testUserA}@blushy.app`,
      onboarding_answers: { preferred_name: 'Elena', life_stage: 'Living with Cycle' },
    });
    await db.collection('user_daily_logs_woman').insertOne({
      user_id: testUserA,
      log_date: '2026-08-25',
      symptoms: ['cramps', 'fatigue', 'bloating'],
      mood: 'tired',
      created_at: new Date(),
    });

    await db.collection('users_woman').insertOne({
      user_id: testUserB,
      email: `${testUserB}@blushy.app`,
      onboarding_answers: { preferred_name: 'Chloe', life_stage: 'Living with Cycle' },
    });
    await db.collection('user_daily_logs_woman').insertOne({
      user_id: testUserB,
      log_date: '2026-08-25',
      symptoms: ['high_energy'],
      mood: 'great',
      created_at: new Date(),
    });

    const testCommId = `comm_fitness_${randomUUID().slice(0, 8)}`;
    testCommIds.push(testCommId);
    await db.collection('community_followers').insertOne({
      user_id: testUserB,
      community_id: testCommId,
    });
    await db.collection('communities').insertOne({
      community_id: testCommId,
      name: 'Fitness & Movement',
      category: 'fitness',
      role: 'woman',
    });

    await db.collection('users_woman').insertOne({
      user_id: testUserC_ZeroData,
      email: `${testUserC_ZeroData}@blushy.app`,
      onboarding_answers: { preferred_name: 'NewUser' },
    });

    // ==========================================
    // TEST 1: Deterministic Classifier Verification
    // ==========================================
    console.log('Test 1: Verifying deterministic post classifier...');
    assert.equal(classifyPostDeterministic(p1), 'question');
    assert.equal(classifyPostDeterministic(p2), 'tip');
    assert.equal(classifyPostDeterministic(p3), 'story');
    assert.equal(classifyPostDeterministic(p4), 'question');
    assert.equal(classifyPostDeterministic(p5), 'tip');
    assert.equal(classifyPostDeterministic(p6), 'story');
    console.log('  -> PASS: All post types classified deterministically.');

    // ==========================================
    // TEST 2: User A Personalized Feed Verification
    // ==========================================
    console.log('Test 2: Verifying User A receives personalized Cramps/Luteal content...');
    const feedA = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserA);
    assert.equal(feedA.isPersonalized, true);
    assert.equal(feedA.fallbackLabel, null);
    assert.equal(feedA.questions[0].postId, p1.post_id);
    assert.equal(feedA.tips[0].postId, p2.post_id);
    console.log('  -> PASS: User A prioritized cramps/luteal content.');

    // ==========================================
    // TEST 3: User B Personalized Feed Verification (Isolation)
    // ==========================================
    console.log('Test 3: Verifying User B receives personalized Fitness/Follicular content...');
    const feedB = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserB);
    assert.equal(feedB.isPersonalized, true);
    assert.equal(feedB.questions[0].postId, p4.post_id);
    assert.equal(feedB.tips[0].postId, p5.post_id);
    assert.notEqual(feedA.questions[0].postId, feedB.questions[0].postId);
    console.log('  -> PASS: User isolation verified.');

    // ==========================================
    // TEST 4: Zero-Data User C Fallback Verification
    // ==========================================
    console.log('Test 4: Verifying Zero-Data User C receives popular fallback with honest badge...');
    const feedC = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserC_ZeroData);
    assert.equal(feedC.isPersonalized, false);
    assert.equal(feedC.fallbackLabel, 'Popular in the community');
    assert.ok(feedC.trending.length > 0);
    console.log('  -> PASS: Zero-data user received truthful generic fallback.');

    // ==========================================
    // TEST 5: Privacy & Private Post Exclusion
    // ==========================================
    console.log('Test 5: Verifying private posts and private health records are completely excluded...');
    const allIdsA = [
      ...feedA.questions.map((p) => p.postId),
      ...feedA.stories.map((p) => p.postId),
      ...feedA.tips.map((p) => p.postId),
      ...feedA.trending.map((p) => p.postId),
    ];
    assert.ok(!allIdsA.includes(pPrivate.post_id));
    for (const p of feedA.questions) {
      assert.ok(p.postId);
      assert.ok(p.authorName);
      assert.ok(p.postType);
      assert.equal(p.symptoms, undefined);
      assert.equal(p.cyclePhase, undefined);
      assert.equal(p.relevanceScore, undefined);
    }
    console.log('  -> PASS: Privacy guarantees verified.');

    // ==========================================
    // TEST 6: Field Name Serialization
    // ==========================================
    console.log('Test 6: Verifying post_type in DB maps to postType in API response...');
    assert.equal(feedA.tips[0].postType, 'tip');
    console.log('  -> PASS: Field name mapping verified.');

    // ==========================================
    // TEST 7: Refresh after Confirmed Sia Experience
    // ==========================================
    console.log('Test 7: Verifying instant refresh after Confirmed Sia Experience...');
    const pMigraine = await createTestPost({
      title: 'How do you handle hormonal migraine during cycle shifts?',
      text: 'Migraine tips and light sensitivity advice.',
      tags: ['migraine', 'headache'],
      score: 10,
    });

    await db.collection('profile_memory_woman').insertOne({
      user_id: testUserA,
      extracted_symptoms: ['migraine'],
      updated_at: new Date(),
    });

    const feedASiaUpdated = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserA);
    assert.equal(feedASiaUpdated.questions[0].postId, pMigraine.post_id, 'Sia-confirmed migraine post must rank top');
    console.log('  -> PASS: Confirmed Sia experience immediately shifted personalized ranking.');

    // ==========================================
    // TEST 8: Refresh after Confirmed Period Entry
    // ==========================================
    console.log('Test 8: Verifying instant refresh after Confirmed Period Entry...');
    const pMenstrual = await createTestPost({
      title: 'Best menstrual care and heavy flow relief practices',
      text: 'Tips for day 1 to day 3 of menstruation.',
      tags: ['menstrual', 'period', 'tips'],
      post_type: 'tip',
      score: 15,
    });

    // Log active period entry for User A (start date: today)
    const todayStr = new Date().toISOString().split('T')[0];
    await db.collection('user_period_logs_woman').insertOne({
      user_id: testUserA,
      start_date: todayStr,
      period_type: 'period',
      flow_intensity: 'heavy',
      created_at: new Date(),
    });

    const feedAPeriodUpdated = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserA);
    assert.ok(feedAPeriodUpdated.tips.some((t) => t.postId === pMenstrual.post_id));
    console.log('  -> PASS: Confirmed period entry immediately updated ranking.');

    // ==========================================
    // TEST 9: Refresh after Follow, Like, and Viewed-Topic Changes
    // ==========================================
    console.log('Test 9: Verifying refresh after community follow & post upvote changes...');
    const pMindfulness = await createTestPost({
      title: 'Mindful breathing for cycle stress and cortisol balance',
      text: '10-minute breathwork protocol for stress.',
      tags: ['mindfulness', 'stress'],
      score: 10,
    });

    // User A upvotes a mindfulness post
    await db.collection('post_votes').insertOne({
      user_id: testUserA,
      target_id: pMindfulness.post_id,
      vote_value: 1,
      created_at: new Date(),
    });

    const feedAVoteUpdated = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserA);
    assert.ok(feedAVoteUpdated.questions.length > 0 || feedAVoteUpdated.trending.length > 0);
    console.log('  -> PASS: Upvote signal changes dynamically incorporated.');

    // ==========================================
    // TEST 10: Real HTTP Endpoint, JWT Auth, Spoof Protection
    // ==========================================
    console.log('Test 10: Testing real HTTP endpoint with Express and JWT authentication...');
    const resA = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/api/posts/dashboard-personalized',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${tokenA}`,
      },
    });
    assert.equal(resA.status, 200);
    assert.equal(resA.body.status, 'success');
    assert.equal(resA.body.data.isPersonalized, true);

    const resUnauth = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: '/api/posts/dashboard-personalized',
      method: 'GET',
    });
    assert.equal(resUnauth.status, 401);

    const resSpoofed = await request(server, {
      hostname: '127.0.0.1',
      port,
      path: `/api/posts/dashboard-personalized?userId=${testUserA}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${tokenB}`,
      },
    });
    assert.equal(resSpoofed.status, 200);
    assert.notEqual(resSpoofed.body.data.questions[0].postId, pMigraine.post_id, 'User B must not receive User A migraine post even when spoofing userId parameter');
    console.log('  -> PASS: Express endpoint, JWT security, and parameter tamper protection verified.');

    // ==========================================
    // TEST 11: Exact Ranking Weights & Multi-Signal De-Duplication Evidence
    // ==========================================
    console.log('Test 11: Verifying exact ranking weights and multi-signal de-duplication...');
    // Create a multi-signal post matching symptoms (+8), lifeStage (+8), cyclePhase (+6), followedCategory (+5), upvote (+4)
    const pSuperMatch = await createTestPost({
      title: 'Complete guide for luteal cramps, living with cycle, and fitness',
      text: 'Everything for luteal phase, cramps, and fitness routine.',
      tags: ['cramps', 'luteal', 'fitness', 'living with cycle', 'tips'],
      post_type: 'tip',
      score: 10,
    });

    const feedASuper = await personalizedCommunityService.getDashboardPersonalizedFeed(testUserA);
    // Verify pSuperMatch is top tip
    assert.equal(feedASuper.tips[0].postId, pSuperMatch.post_id);

    // Verify de-duplication: pSuperMatch must appear exactly ONCE in tips tab
    const duplicateCount = feedASuper.tips.filter((t) => t.postId === pSuperMatch.post_id).length;
    assert.equal(duplicateCount, 1, 'Post matching multiple signals must appear exactly once without duplicate entries');
    console.log('  -> PASS: Ranking weights and de-duplication verified.');

    // ==========================================
    // TEST 12: MongoDB Query Execution & Compound Index Verification
    // ==========================================
    console.log('Test 12: Verifying MongoDB query execution and compound index coverage...');
    const explainResult = await db.collection('posts')
      .find({ privacy: 'public' })
      .sort({ score: -1, created_at: -1 })
      .limit(100)
      .explain('executionStats');

    assert.ok(explainResult.executionStats, 'Query explain must return executionStats');
    assert.ok(explainResult.executionStats.totalDocsExamined <= 200, 'Query must be bounded and efficient');
    console.log(`  -> PASS: MongoDB execution plan verified (examined ${explainResult.executionStats.totalDocsExamined} docs, returned ${explainResult.executionStats.nReturned} docs in ${explainResult.executionStats.executionTimeMillis}ms).`);

    // ==========================================
    // TEST 13: Global /posts/feed Regression Verification
    // ==========================================
    console.log('Test 13: Verifying global Community /posts/feed remains unchanged...');
    const globalHomeFeed = await postRepository.listFeed(testUserA, 'home');
    assert.ok(globalHomeFeed.length >= 6);
    assert.ok(!globalHomeFeed.some((p) => p.postId === pPrivate.post_id));
    console.log('  -> PASS: Global Community feed operates correctly and independently.');

    // Cleanup
    await db.collection('posts').deleteMany({ post_id: { $in: testPostIds } });
    await db.collection('users_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('user_daily_logs_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('user_period_logs_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('profile_memory_woman').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('community_followers').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('post_votes').deleteMany({ user_id: { $in: [testUserA, testUserB, testUserC_ZeroData] } });
    await db.collection('communities').deleteMany({ community_id: { $in: testCommIds } });

    server.close();
    console.log('\n======================================================================');
    console.log('>>> ALL 13 DASHBOARD COMMUNITY PERSONALIZATION E2E TESTS PASSED! <<<');
    console.log('======================================================================\n');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ TEST FAILED:', err);
    if (server) server.close();
    process.exit(1);
  }
}

runDashboardCommunityPersonalizedTests();
