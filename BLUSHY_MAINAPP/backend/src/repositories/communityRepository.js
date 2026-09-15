import { randomUUID } from 'node:crypto';

import { db, findUserDocuments } from '../utils/db.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

function normalizeStoredRole(role) {
  return normalizeRoleValue(role, 'woman');
}

function mapCommunityRow(row) {
  if (!row) {
    return null;
  }

  return {
    communityId: row.community_id,
    name: row.name,
    description: row.description,
    category: row.category,
    role: row.role,
    creatorUserId: row.creator_user_id,
    privacy: row.privacy ?? 'public',
    profilePicUrl: row.profile_pic_url,
    currentUserRole: row.current_user_role ?? 'none',
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
    followerCount: Number(row.follower_count ?? 0),
    isFollowing: Boolean(row.is_following),
    isPending: Boolean(row.is_pending),
  };
}

function mapMessageRow(row) {
  return {
    messageId: row.message_id,
    communityId: row.community_id,
    senderUserId: row.sender_user_id,
    role: row.role,
    text: row.text,
    imageUrl: row.image_url,
    createdAt: new Date(row.created_at).toISOString(),
  };
}

async function createCommunity({ name, description, category, role, creatorUserId, privacy = 'public' }) {
  const communityId = randomUUID();
  const safeRole = normalizeStoredRole(role);
  const safePrivacy = privacy === 'private' ? 'private' : 'public';
  const now = new Date();

  await db.collection('communities').insertOne({
    community_id: communityId,
    name,
    description,
    category,
    role: safeRole,
    creator_user_id: creatorUserId,
    privacy: safePrivacy,
    profile_pic_url: null,
    created_at: now,
    updated_at: now,
  });

  await db.collection('community_followers').updateOne(
    { community_id: communityId, user_id: creatorUserId },
    {
      $set: { status: 'accepted', role: 'admin' },
      $setOnInsert: { created_at: now }
    },
    { upsert: true }
  );

  const created = await getCommunityForViewer(communityId, creatorUserId);
  return created;
}

async function getCommunityForViewer(communityId, viewerUserId) {
  const community = await db.collection('communities').findOne({ community_id: communityId });
  if (!community) {
    return null;
  }

  const followers = await db.collection('community_followers')
    .find({ community_id: communityId })
    .toArray();

  const followerCount = followers.filter(f => f.status === 'accepted').length;
  const isFollowing = followers.some(f => f.user_id === viewerUserId && f.status === 'accepted');
  const isPending = followers.some(f => f.user_id === viewerUserId && f.status === 'pending');
  const viewerFollower = followers.find(f => f.user_id === viewerUserId);
  const currentUserRole = viewerFollower ? (viewerFollower.role || 'none') : 'none';

  const row = {
    ...community,
    follower_count: followerCount,
    is_following: isFollowing,
    is_pending: isPending,
    current_user_role: currentUserRole,
  };

  return mapCommunityRow(row);
}

async function getCommunityById(communityId) {
  const row = await db.collection('communities').findOne({ community_id: communityId });
  if (!row) {
    return null;
  }

  return {
    communityId: row.community_id,
    name: row.name,
    description: row.description,
    category: row.category,
    role: row.role,
    creatorUserId: row.creator_user_id,
    privacy: row.privacy ?? 'public',
    profilePicUrl: row.profile_pic_url,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

async function listCommunitiesForRole(role, viewerUserId) {
  const safeRole = normalizeStoredRole(role);

  const communities = await db.collection('communities')
    .find({ role: safeRole })
    .toArray();

  if (communities.length === 0) {
    return [];
  }

  const communityIds = communities.map(c => c.community_id);

  const allFollowers = await db.collection('community_followers')
    .find({ community_id: { $in: communityIds } })
    .toArray();

  const followersByCommunity = {};
  for (const f of allFollowers) {
    if (!followersByCommunity[f.community_id]) {
      followersByCommunity[f.community_id] = [];
    }
    followersByCommunity[f.community_id].push(f);
  }

  return communities.map(c => {
    const followers = followersByCommunity[c.community_id] || [];

    const followerCount = followers.filter(f => f.status === 'accepted').length;
    const isFollowing = followers.some(f => f.user_id === viewerUserId && f.status === 'accepted');
    const isPending = followers.some(f => f.user_id === viewerUserId && f.status === 'pending');
    const viewerFollower = followers.find(f => f.user_id === viewerUserId);
    const currentUserRole = viewerFollower ? (viewerFollower.role || 'none') : 'none';

    const row = {
      ...c,
      follower_count: followerCount,
      is_following: isFollowing,
      is_pending: isPending,
      current_user_role: currentUserRole,
    };

    return mapCommunityRow(row);
  });
}

async function followCommunity(communityId, userId) {
  const community = await getCommunityById(communityId);
  if (!community) {
    return null;
  }

  const initialStatus = 'accepted';
  const now = new Date();

  await db.collection('community_followers').updateOne(
    { community_id: communityId, user_id: userId },
    {
      $set: { status: initialStatus },
      $setOnInsert: { role: 'member', created_at: now }
    },
    { upsert: true }
  );

  await db.collection('communities').updateOne(
    { community_id: communityId },
    { $set: { updated_at: now } }
  );

  return getCommunityForViewer(communityId, userId);
}

async function unfollowCommunity(communityId, userId) {
  const community = await getCommunityById(communityId);
  if (!community) {
    return null;
  }

  const now = new Date();

  if (community.creatorUserId !== userId) {
    await db.collection('community_followers').deleteOne({
      community_id: communityId,
      user_id: userId,
    });
  }

  await db.collection('communities').updateOne(
    { community_id: communityId },
    { $set: { updated_at: now } }
  );

  return getCommunityForViewer(communityId, userId);
}

async function deleteCommunity(communityId, userId) {
  const community = await getCommunityById(communityId);
  if (!community) {
    return false;
  }

  if (community.creatorUserId !== userId) {
    return false;
  }

  await db.collection('community_messages').deleteMany({ community_id: communityId });
  await db.collection('community_followers').deleteMany({ community_id: communityId });
  await db.collection('communities').deleteOne({ community_id: communityId });

  return true;
}

async function isFollowing(communityId, userId) {
  const follower = await db.collection('community_followers').findOne({
    community_id: communityId,
    user_id: userId,
    status: 'accepted'
  });

  return Boolean(follower);
}

async function addMessage({ communityId, senderUserId, role, text, imageUrl }) {
  const messageId = randomUUID();
  const safeText = typeof text === 'string' ? text : '';
  const now = new Date();

  const messageDoc = {
    message_id: messageId,
    community_id: communityId,
    sender_user_id: senderUserId,
    role: normalizeStoredRole(role),
    text: safeText,
    image_url: imageUrl,
    created_at: now,
  };

  await db.collection('community_messages').insertOne(messageDoc);

  await db.collection('communities').updateOne(
    { community_id: communityId },
    { $set: { updated_at: now } }
  );

  return mapMessageRow(messageDoc);
}

async function listMessages(communityId) {
  const messages = await db.collection('community_messages')
    .find({ community_id: communityId })
    .sort({ created_at: 1 })
    .toArray();

  return messages.map(mapMessageRow);
}

async function listPendingRequests(communityId) {
  const followers = await db.collection('community_followers')
    .find({ community_id: communityId, status: 'pending' })
    .sort({ created_at: 1 })
    .toArray();

  if (followers.length === 0) {
    return [];
  }

  const userIds = followers.map(cf => cf.user_id);
  const users = await findUserDocuments({ user_id: { $in: userIds } });

  const usersMap = {};
  for (const u of users) {
    usersMap[u.user_id] = u;
  }

  const list = [];
  for (const cf of followers) {
    const u = usersMap[cf.user_id];
    if (u) {
      list.push({
        userId: u.user_id,
        email: u.email,
        displayName: u.onboarding_answers?.preferred_name ?? 'Anonymous User',
        createdAt: new Date(cf.created_at).toISOString(),
      });
    }
  }

  return list;
}

async function approveRequest(communityId, userId) {
  await db.collection('community_followers').updateOne(
    { community_id: communityId, user_id: userId },
    { $set: { status: 'accepted' } }
  );
  return true;
}

async function rejectRequest(communityId, userId) {
  await db.collection('community_followers').deleteOne({
    community_id: communityId,
    user_id: userId,
    status: 'pending'
  });
  return true;
}

async function listGroupMembers(communityId) {
  const followers = await db.collection('community_followers')
    .find({ community_id: communityId, status: 'accepted' })
    .toArray();

  if (followers.length === 0) {
    return [];
  }

  const userIds = followers.map(cf => cf.user_id);
  const users = await findUserDocuments({ user_id: { $in: userIds } });

  const usersMap = {};
  for (const u of users) {
    usersMap[u.user_id] = u;
  }

  const members = [];
  for (const cf of followers) {
    const u = usersMap[cf.user_id];
    if (u) {
      members.push({
        userId: u.user_id,
        email: u.email,
        displayName: u.onboarding_answers?.preferred_name ?? 'Anonymous User',
        role: cf.role,
        createdAt: new Date(cf.created_at).toISOString(),
      });
    }
  }

  members.sort((a, b) => {
    const roleA = a.role === 'admin' ? 1 : 2;
    const roleB = b.role === 'admin' ? 1 : 2;
    if (roleA !== roleB) {
      return roleA - roleB;
    }
    return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
  });

  return members;
}

async function promoteMemberToAdmin(communityId, userId) {
  await db.collection('community_followers').updateOne(
    { community_id: communityId, user_id: userId, status: 'accepted' },
    { $set: { role: 'admin' } }
  );
  return true;
}

async function updateGroupDetails(communityId, { name, description, profilePicUrl }) {
  const updates = {};

  if (name !== undefined) {
    updates.name = name;
  }
  if (description !== undefined) {
    updates.description = description;
  }
  if (profilePicUrl !== undefined) {
    updates.profile_pic_url = profilePicUrl;
  }

  if (Object.keys(updates).length === 0) return true;

  updates.updated_at = new Date();

  await db.collection('communities').updateOne(
    { community_id: communityId },
    { $set: updates }
  );
  return true;
}

async function getMemberRole(communityId, userId) {
  const follower = await db.collection('community_followers').findOne({
    community_id: communityId,
    user_id: userId,
    status: 'accepted'
  });
  return follower?.role ?? 'none';
}

function serializeCommunity(community) {
  return community;
}

export const communityRepository = {
  createCommunity,
  getCommunityById,
  getCommunityForViewer,
  listCommunitiesForRole,
  followCommunity,
  unfollowCommunity,
  deleteCommunity,
  isFollowing,
  addMessage,
  listMessages,
  listPendingRequests,
  approveRequest,
  rejectRequest,
  listGroupMembers,
  promoteMemberToAdmin,
  updateGroupDetails,
  getMemberRole,
  serializeCommunity,
};
