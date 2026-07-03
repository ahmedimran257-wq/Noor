export interface ClientPhotoModerationPayload {
  status: "safe" | "pendingReview" | "unsafe" | "scanFailed";
  is_nsfw: boolean;
  requires_review?: boolean;
  confidence: number;
  category: string;
  threshold: number;
}

export type PhotoValidationAction = "reject" | "pending_review";

export function resolveClientModerationVerdict(
  moderation: ClientPhotoModerationPayload,
): PhotoValidationAction {
  const shapeIsValid = typeof moderation === "object" &&
    moderation !== null &&
    Number.isFinite(moderation.confidence) &&
    moderation.confidence >= 0 &&
    moderation.confidence <= 1 &&
    Number.isFinite(moderation.threshold) &&
    moderation.threshold >= 0 &&
    moderation.threshold <= 1 &&
    typeof moderation.category === "string" &&
    moderation.category.length > 0;

  if (!shapeIsValid) return "reject";
  if (moderation.status === "unsafe" || moderation.status === "scanFailed") {
    return "reject";
  }
  if (moderation.is_nsfw === true) return "reject";

  // Client-side moderation is evidence, not approval authority. Without a
  // server-side scanner or a staff decision, photos must remain out of public
  // discovery even when the client reports "safe".
  return "pending_review";
}
