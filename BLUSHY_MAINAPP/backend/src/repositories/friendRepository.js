import { db, findUserDocuments } from '../utils/db.js';

function mapUserRow(row, viewerUserId) {
  if (!row) return null;
  return {
    userId: row.user_id,
    email: row.email,
    displayName: row.onboarding_answers?.preferred_name ?? 'Anonymous User',
    friendshipStatus: row.friendship_status ?? null, // 'pending', 'accepted', or null
    friendshipInitiator: row.friendship_initiator ?? null, // who initiated the request
  };
}

async function searchUsers(queryText, viewerUserId) {
  const escaped = queryText.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(escaped, 'i');

  const users = await findUserDocuments({
    user_id: { $ne: viewerUserId },
    $or: [
      { email: { $regex: regex } },
      { 'onboarding_answers.preferred_name': { $regex: regex } }
    ]
  });

  const limitedUsers = users.slice(0, 20);
  const userIds = limitedUsers.map(u => u.user_id);
  
  const friendships = await db.collection('friendships')
    .find({
      $or: [
        { user_id_1: viewerUserId, user_id_2: { $in: userIds } },
        { user_id_1: { $in: userIds }, user_id_2: viewerUserId }
      ]
    })
    .toArray();

  const friendshipMap = {};
  friendships.forEach(f => {
    const otherId = f.user_id_1 === viewerUserId ? f.user_id_2 : f.user_id_1;
    friendshipMap[otherId] = f;
  });

  return limitedUsers.map(u => {
    const f = friendshipMap[u.user_id];
    return mapUserRow({
      user_id: u.user_id,
      email: u.email,
      onboarding_answers: u.onboarding_answers,
      friendship_status: f ? f.status : null,
      friendship_initiator: f ? f.user_id_1 : null
    }, viewerUserId);
  });
}

async function sendFriendRequest(senderId, recipientId) {
  const existing = await db.collection('friendships').findOne({
    $or: [
      { user_id_1: senderId, user_id_2: recipientId },
      { user_id_1: recipientId, user_id_2: senderId }
    ]
  });

  if (existing) {
    return false; // Already exists
  }

  await db.collection('friendships').insertOne({
    user_id_1: senderId,
    user_id_2: recipientId,
    status: 'pending',
    created_at: new Date()
  });
  return true;
}

async function acceptFriendRequest(recipientId, senderId) {
  const result = await db.collection('friendships').updateOne(
    { user_id_1: senderId, user_id_2: recipientId, status: 'pending' },
    { $set: { status: 'accepted' } }
  );

  return result.matchedCount > 0;
}

async function rejectFriendRequest(recipientId, senderId) {
  const result = await db.collection('friendships').deleteOne({
    user_id_1: senderId,
    user_id_2: recipientId,
    status: 'pending'
  });

  return result.deletedCount > 0;
}

async function listFriends(userId) {
  const friendships = await db.collection('friendships')
    .find({
      $or: [
        { user_id_1: userId },
        { user_id_2: userId }
      ],
      status: 'accepted'
    })
    .toArray();

  const friendIds = friendships.map(f => f.user_id_1 === userId ? f.user_id_2 : f.user_id_1);

  const friends = await findUserDocuments({ user_id: { $in: friendIds } });

  const mappedFriends = friends.map(u => {
    return mapUserRow({
      user_id: u.user_id,
      email: u.email,
      onboarding_answers: u.onboarding_answers,
      friendship_status: 'accepted'
    }, userId);
  });

  mappedFriends.sort((a, b) => {
    const nameA = a.displayName.toLowerCase();
    const nameB = b.displayName.toLowerCase();
    return nameA.localeCompare(nameB);
  });

  return mappedFriends;
}

async function listPendingRequests(userId) {
  const pendingFriendships = await db.collection('friendships')
    .find({ user_id_2: userId, status: 'pending' })
    .sort({ created_at: 1 })
    .toArray();

  const senderIds = pendingFriendships.map(f => f.user_id_1);

  const senders = await findUserDocuments({ user_id: { $in: senderIds } });

  const senderMap = {};
  senders.forEach(u => {
    senderMap[u.user_id] = u;
  });

  const result = [];
  for (const f of pendingFriendships) {
    const u = senderMap[f.user_id_1];
    if (u) {
      result.push(
        mapUserRow({
          user_id: u.user_id,
          email: u.email,
          onboarding_answers: u.onboarding_answers,
          friendship_status: 'pending',
          friendship_initiator: f.user_id_1
        }, userId)
      );
    }
  }

  return result;
}

export const friendRepository = {
  searchUsers,
  sendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  listFriends,
  listPendingRequests,
};
