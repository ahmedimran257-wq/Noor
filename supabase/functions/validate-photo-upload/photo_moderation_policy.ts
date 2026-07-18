export interface ClientPhotoModerationPayload {
  policy_version: number;
  status: "approved" | "flagged" | "rejected" | "scanFailed";
  is_nsfw: boolean;
  requires_review?: boolean;
  confidence: number;
  nsfw_confidence: number;
  safe_confidence: number;
  category: string;
  threshold: number;
}

export type PhotoValidationAction = "reject" | "approved" | "flagged";

export const PHOTO_MODERATION_POLICY_VERSION = 3;
export const NSFW_FLAG_THRESHOLD = 0.85;

export function resolveClientModerationVerdict(
  moderation: ClientPhotoModerationPayload,
): PhotoValidationAction {
  const shapeIsValid = typeof moderation === "object" &&
    moderation !== null &&
    moderation.policy_version === PHOTO_MODERATION_POLICY_VERSION &&
    Number.isFinite(moderation.confidence) &&
    moderation.confidence >= 0 &&
    moderation.confidence <= 1 &&
    Number.isFinite(moderation.nsfw_confidence) &&
    moderation.nsfw_confidence >= 0 &&
    moderation.nsfw_confidence <= 1 &&
    Number.isFinite(moderation.safe_confidence) &&
    moderation.safe_confidence >= 0 &&
    moderation.safe_confidence <= 1 &&
    Number.isFinite(moderation.threshold) &&
    moderation.threshold >= 0 &&
    moderation.threshold <= 1 &&
    typeof moderation.category === "string" &&
    moderation.category.length > 0;

  if (!shapeIsValid) return "reject";
  const nsfw = moderation.nsfw_confidence;
  // Server thresholds are authoritative. The client-provided threshold is
  // telemetry only and cannot weaken this policy.
  const requiresReview = nsfw > NSFW_FLAG_THRESHOLD;
  if (requiresReview) {
    return moderation.status === "flagged" &&
        moderation.is_nsfw === true &&
        moderation.requires_review === true &&
        moderation.category === "explicit_content"
      ? "flagged"
      : "reject";
  }

  if (
    moderation.status !== "approved" ||
    moderation.is_nsfw === true ||
    moderation.requires_review === true ||
    moderation.category !== "safe_image"
  ) {
    return "reject";
  }
  return "approved";
}
