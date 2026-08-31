import { communityRepository } from '../repositories/communityRepository.js';
import { userRepository } from '../repositories/userRepository.js';
import { createHttpError } from '../utils/httpError.js';
import { normalizeRole as normalizeRoleValue } from '../utils/role.js';

async function requireAuthUserAsync(req) {
  const userId = req.user?.userId;
  if (!userId) {
    throw createHttpError(401, 'Authentication required.');
  }

  // The auth middleware already read this record and checked it, and it put
  // the database role on req.user. Reading it again here meant every
  // authenticated request paid for the same lookup twice.
  if (req.user?.verifiedAgainstDb) {
    return { userId, role: normalizeRoleValue(req.user.role, 'woman') };
  }

  // No middleware vouched for the request, so verify it here.
  const user = await userRepository.getUserById(userId);
  if (!user) {
    throw createHttpError(404, 'User not found.');
  }

  return { userId, role: normalizeRoleValue(user.role, 'woman') };
}

function isAllowedImageUrl(url) {
  if (typeof url !== 'string' || url.trim().length === 0) {
    return false;
  }

  const trimmed = url.trim();
  if (!/^https?:\/\//i.test(trimmed)) {
    return false;
  }

  if (/\.(gif|mp4|mov|avi|mkv|webm)(\?|$)/i.test(trimmed)) {
    return false;
  }

  return /\.(png|jpg|jpeg|webp|bmp|heic|heif)(\?|$)/i.test(trimmed);
}

export async function listCommunities(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const search = String(req.query?.search ?? '').trim().toLowerCase();
    const filter = String(req.query?.filter ?? 'all').toLowerCase();

    let communities = (await communityRepository
      .listCommunitiesForRole(auth.role, auth.userId))
      .map((community) => communityRepository.serializeCommunity(community, auth.userId));

    if (search.length > 0) {
      communities = communities.filter((community) => {
        const haystack = `${community.name} ${community.description} ${community.category}`.toLowerCase();
        return haystack.includes(search);
      });
    }

    if (filter === 'following') {
      communities = communities.filter((community) => community.isFollowing);
    } else if (filter === 'discover') {
      communities = communities.filter((community) => !community.isFollowing);
    }

    communities.sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1));

    res.status(200).json({ communities });
  } catch (error) {
    next(error);
  }
}

export async function createCommunity(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const name = typeof req.body?.name === 'string' ? req.body.name.trim() : '';
    const description = typeof req.body?.description === 'string' ? req.body.description.trim() : '';
    const category = typeof req.body?.category === 'string' ? req.body.category.trim() : '';
    const communityType = typeof req.body?.communityType === 'string' ? req.body.communityType.trim().toLowerCase() : auth.role;
    const privacy = typeof req.body?.privacy === 'string' ? req.body.privacy.trim().toLowerCase() : 'public';

    if (name.length < 3) {
      throw createHttpError(400, 'Community name must be at least 3 characters.');
    }

    if (description.length < 10) {
      throw createHttpError(400, 'Description must be at least 10 characters.');
    }

    if (category.length < 2) {
      throw createHttpError(400, 'Category must be at least 2 characters.');
    }

    if (communityType !== auth.role) {
      throw createHttpError(403, `You can only create ${auth.role} communities.`);
    }

    const community = await communityRepository.createCommunity({
      name,
      description,
      category,
      role: communityType,
      creatorUserId: auth.userId,
      privacy: privacy === 'private' ? 'private' : 'public',
    });

    res.status(201).json({
      community: communityRepository.serializeCommunity(community, auth.userId),
    });
  } catch (error) {
    next(error);
  }
}

export async function followCommunity(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    if (community.role !== auth.role) {
      throw createHttpError(403, 'You can only follow communities for your role.');
    }

    const updated = await communityRepository.followCommunity(communityId, auth.userId);
    res.status(200).json({
      community: communityRepository.serializeCommunity(updated, auth.userId),
    });
  } catch (error) {
    next(error);
  }
}

export async function unfollowCommunity(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    if (community.role !== auth.role) {
      throw createHttpError(403, 'You can only manage communities for your role.');
    }

    const updated = await communityRepository.unfollowCommunity(communityId, auth.userId);
    res.status(200).json({
      community: communityRepository.serializeCommunity(updated, auth.userId),
    });
  } catch (error) {
    next(error);
  }
}

export async function deleteCommunity(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();

    const deleted = await communityRepository.deleteCommunity(communityId, auth.userId);
    if (!deleted) {
      throw createHttpError(403, 'You can only delete communities that you created.');
    }

    res.status(200).json({
      message: 'Community deleted successfully.',
    });
  } catch (error) {
    next(error);
  }
}

export async function listMessages(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    if (community.role !== auth.role) {
      throw createHttpError(403, 'Access denied for this community.');
    }

    if (!(await communityRepository.isFollowing(community.communityId, auth.userId))) {
      throw createHttpError(403, 'Join this community to view and send messages.');
    }

    const messages = await communityRepository.listMessages(communityId);
    res.status(200).json({ messages });
  } catch (error) {
    next(error);
  }
}

export async function sendMessage(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    const rawImageUrl = typeof req.body?.imageUrl === 'string' ? req.body.imageUrl.trim() : '';
    const uploadedImage = req.file;

    const community = await communityRepository.getCommunityById(communityId);
    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    if (community.role !== auth.role) {
      throw createHttpError(403, 'Access denied for this community.');
    }

    if (!(await communityRepository.isFollowing(community.communityId, auth.userId))) {
      throw createHttpError(403, 'Join this community to send messages.');
    }

    const hasText = text.length > 0;
    const hasImage = rawImageUrl.length > 0 || Boolean(uploadedImage);

    if (!hasText && !hasImage) {
      throw createHttpError(400, 'Send text or an image URL.');
    }

    if (rawImageUrl.length > 0 && !isAllowedImageUrl(rawImageUrl)) {
      throw createHttpError(400, 'Only image URLs are supported (png/jpg/jpeg/webp/bmp/heic). GIF/videos are not allowed.');
    }

    const uploadedImageUrl = uploadedImage
      ? `${req.protocol}://${req.get('host')}/uploads/community/${uploadedImage.filename}`
      : null;

    const message = await communityRepository.addMessage({
      communityId,
      senderUserId: auth.userId,
      role: auth.role,
      text,
      imageUrl: uploadedImageUrl ?? (rawImageUrl.length > 0 ? rawImageUrl : null),
    });

    res.status(201).json({ message });
  } catch (error) {
    next(error);
  }
}

export async function listPendingRequests(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    const userRole = await communityRepository.getMemberRole(communityId, auth.userId);
    if (userRole !== 'admin' && community.creatorUserId !== auth.userId) {
      throw createHttpError(403, 'Only admins can view pending requests.');
    }

    const requests = await communityRepository.listPendingRequests(communityId);
    res.status(200).json({ requests });
  } catch (error) {
    next(error);
  }
}

export async function approveRequest(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const userId = String(req.params?.userId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    const userRole = await communityRepository.getMemberRole(communityId, auth.userId);
    if (userRole !== 'admin' && community.creatorUserId !== auth.userId) {
      throw createHttpError(403, 'Only admins can approve requests.');
    }

    await communityRepository.approveRequest(communityId, userId);
    res.status(200).json({ message: 'Request approved successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function rejectRequest(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const userId = String(req.params?.userId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    const userRole = await communityRepository.getMemberRole(communityId, auth.userId);
    if (userRole !== 'admin' && community.creatorUserId !== auth.userId) {
      throw createHttpError(403, 'Only admins can reject requests.');
    }

    await communityRepository.rejectRequest(communityId, userId);
    res.status(200).json({ message: 'Request rejected successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function listGroupMembers(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    if (community.role !== auth.role) {
      throw createHttpError(403, 'Access denied for this community.');
    }

    if (!(await communityRepository.isFollowing(communityId, auth.userId))) {
      throw createHttpError(403, 'Join this community to view members.');
    }

    const members = await communityRepository.listGroupMembers(communityId);
    res.status(200).json({ members });
  } catch (error) {
    next(error);
  }
}

export async function promoteMember(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const userId = String(req.params?.userId ?? '').trim();
    const community = await communityRepository.getCommunityById(communityId);

    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    const callerRole = await communityRepository.getMemberRole(communityId, auth.userId);
    if (callerRole !== 'admin' && community.creatorUserId !== auth.userId) {
      throw createHttpError(403, 'Only admins can promote other members.');
    }

    await communityRepository.promoteMemberToAdmin(communityId, userId);
    res.status(200).json({ message: 'Member promoted to admin successfully.' });
  } catch (error) {
    next(error);
  }
}

export async function updateDetails(req, res, next) {
  try {
    const auth = await requireAuthUserAsync(req);
    const communityId = String(req.params?.communityId ?? '').trim();
    const name = typeof req.body?.name === 'string' ? req.body.name.trim() : undefined;
    const description = typeof req.body?.description === 'string' ? req.body.description.trim() : undefined;
    const rawImageUrl = typeof req.body?.profilePicUrl === 'string' ? req.body.profilePicUrl.trim() : undefined;
    const uploadedImage = req.file;

    const community = await communityRepository.getCommunityById(communityId);
    if (!community) {
      throw createHttpError(404, 'Community not found.');
    }

    const callerRole = await communityRepository.getMemberRole(communityId, auth.userId);
    if (callerRole !== 'admin' && community.creatorUserId !== auth.userId) {
      throw createHttpError(403, 'Only admins can update group details.');
    }

    const uploadedImageUrl = uploadedImage
      ? `${req.protocol}://${req.get('host')}/uploads/community/${uploadedImage.filename}`
      : undefined;

    await communityRepository.updateGroupDetails(communityId, {
      name,
      description,
      profilePicUrl: uploadedImageUrl ?? rawImageUrl,
    });

    const updated = await communityRepository.getCommunityForViewer(communityId, auth.userId);
    res.status(200).json({ community: updated });
  } catch (error) {
    next(error);
  }
}
