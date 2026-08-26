import { randomUUID } from 'node:crypto';
import { db } from '../utils/db.js';

function mapMessageRow(row) {
  if (!row) return null;
  return {
    messageId: row.message_id,
    senderId: row.sender_id,
    recipientId: row.recipient_id,
    text: row.text,
    imageUrl: row.image_url,
    createdAt: new Date(row.created_at).toISOString(),
  };
}

async function isFriend(userId, friendId) {
  const friendship = await db.collection('friendships').findOne({
    $or: [
      { user_id_1: userId, user_id_2: friendId },
      { user_id_1: friendId, user_id_2: userId }
    ],
    status: 'accepted'
  });
  return !!friendship;
}

async function addMessage({ senderId, recipientId, text, imageUrl }) {
  // Ensure they are friends
  const friends = await isFriend(senderId, recipientId);
  if (!friends) {
    throw new Error('You can only message accepted friends.');
  }

  const messageId = randomUUID();
  const doc = {
    message_id: messageId,
    sender_id: senderId,
    recipient_id: recipientId,
    text,
    image_url: imageUrl,
    created_at: new Date()
  };

  await db.collection('direct_messages').insertOne(doc);

  return mapMessageRow(doc);
}

async function listMessages(userId, friendId) {
  // Ensure they are friends
  const friends = await isFriend(userId, friendId);
  if (!friends) {
    throw new Error('You can only view messages with accepted friends.');
  }

  const messages = await db.collection('direct_messages').find({
    $or: [
      { sender_id: userId, recipient_id: friendId },
      { sender_id: friendId, recipient_id: userId }
    ]
  })
  .sort({ created_at: 1 })
  .toArray();

  return messages.map(mapMessageRow);
}

async function listConversations(userId) {
  const pipeline = [
    {
      $match: {
        $or: [
          { sender_id: userId },
          { recipient_id: userId }
        ]
      }
    },
    {
      $sort: { created_at: -1 }
    },
    {
      $group: {
        _id: {
          $cond: {
            if: { $eq: ['$sender_id', userId] },
            then: '$recipient_id',
            else: '$sender_id'
          }
        },
        last_message: { $first: '$$ROOT' }
      }
    },
    {
      $lookup: {
        from: 'users',
        localField: '_id',
        foreignField: 'user_id',
        as: 'other_user'
      }
    },
    {
      $unwind: '$other_user'
    },
    {
      $sort: { 'last_message.created_at': -1 }
    }
  ];

  const result = await db.collection('direct_messages').aggregate(pipeline).toArray();

  return result.map(row => ({
    otherUser: {
      userId: row.other_user.user_id,
      email: row.other_user.email,
      displayName: row.other_user.onboarding_answers?.preferred_name ?? 'Anonymous User',
    },
    lastMessage: {
      messageId: row.last_message.message_id,
      senderId: row.last_message.sender_id,
      recipientId: row.last_message.recipient_id,
      text: row.last_message.text,
      imageUrl: row.last_message.image_url,
      createdAt: new Date(row.last_message.created_at).toISOString(),
    }
  }));
}

export const directMessageRepository = {
  addMessage,
  listMessages,
  listConversations,
};
