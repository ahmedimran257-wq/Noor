export interface ClientPhotoModerationPayload {
  status: "approved" | "flagged" | "rejected" | "scanFailed";
  is_nsfw: boolean;
  requires_review?: boolean;
  confidence: number;
  category: string;
  threshold: number;
}

export type PhotoValidationAction = "reject" | "approved" | "flagged";

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
  if (moderation.status === "rejected" || moderation.status === "scanFailed") {
    return "reject";
  }
  if (
    moderation.status === "flagged" &&
    moderation.is_nsfw === true &&
    moderation.category === "explicit_content" &&
    moderation.confidence > 0.85
  ) return "flagged";
  if (moderation.status !== "approved" || moderation.is_nsfw === true) {
    return "reject";
  }
  return "approved";
}
