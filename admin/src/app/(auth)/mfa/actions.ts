"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const requestTimeoutMs = 10000;
const pendingMfaCookieName = "silarah_admin_pending_mfa";

export type PendingMfaFactor = {
  factorId: string;
  uri: string;
};

async function withTimeout<T>(request: PromiseLike<T>): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race([
      request,
      new Promise<T>((_, reject) => {
        timeoutId = setTimeout(
          () => reject(new Error("Security request timed out.")),
          requestTimeoutMs,
        );
      }),
    ]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}

async function getAuthenticatedClient() {
  const supabase = await createClient();
  const {
    data: { user },
    error,
  } = await withTimeout(supabase.auth.getUser());
  if (error || !user) {
    return { error: "Your staff session has expired. Please sign in again." } as const;
  }

  const { data: membership, error: membershipError } = await withTimeout(
    supabase
      .from("admin_memberships")
      .select("user_id")
      .eq("user_id", user.id)
      .eq("status", "active")
      .maybeSingle(),
  );
  if (membershipError || !membership) {
    return { error: "This account is not an active Silarah staff account." } as const;
  }

  return { supabase, user } as const;
}

async function setPendingMfaFactor(userId: string, factor: PendingMfaFactor) {
  const cookieStore = await cookies();
  cookieStore.set(pendingMfaCookieName, JSON.stringify({ userId, ...factor }), {
    httpOnly: true,
    maxAge: 10 * 60,
    path: "/mfa",
    sameSite: "strict",
    secure: process.env.NODE_ENV === "production",
  });
}

async function clearPendingMfaFactor() {
  const cookieStore = await cookies();
  cookieStore.delete(pendingMfaCookieName);
}

export async function getPendingMfaFactor(userId: string): Promise<PendingMfaFactor | undefined> {
  const cookieStore = await cookies();
  const raw = cookieStore.get(pendingMfaCookieName)?.value;
  if (!raw) return undefined;

  try {
    const parsed = z
      .object({ userId: z.string().uuid(), factorId: z.string().uuid(), uri: z.string().url() })
      .parse(JSON.parse(raw));
    if (parsed.userId !== userId) return undefined;
    return { factorId: parsed.factorId, uri: parsed.uri };
  } catch {
    return undefined;
  }
}

export async function getVerifiedMfaFactorId() {
  try {
    const session = await getAuthenticatedClient();
    if ("error" in session) return undefined;

    const { data, error } = await withTimeout(session.supabase.auth.mfa.listFactors());
    if (error) return undefined;
    return data?.totp.find((factor) => factor.status === "verified")?.id;
  } catch {
    return undefined;
  }
}

async function enrollAuthenticator() {
  try {
    const session = await getAuthenticatedClient();
    if ("error" in session) return { ok: false as const, message: session.error };

    const { data, error } = await withTimeout(
      session.supabase.auth.mfa.enroll({
        factorType: "totp",
        friendlyName: "Silarah Admin",
      }),
    );
    if (error || !data) {
      return { ok: false as const, message: "Authenticator setup could not be started. Please try again." };
    }

    return {
      ok: true as const,
      userId: session.user.id,
      factorId: data.id,
      uri: data.totp.uri,
    };
  } catch {
    return { ok: false as const, message: "The security service did not respond. Please try again." };
  }
}

const replacementSchema = z.object({
  factorId: z.string().uuid(),
  password: z.string().min(8),
});

async function replaceAuthenticator(input: { factorId: string; password: string }) {
  const parsed = replacementSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false as const, message: "Enter your current staff password to replace the authenticator." };
  }

  try {
    const session = await getAuthenticatedClient();
    if ("error" in session) return { ok: false as const, message: session.error };
    if (!session.user.email) {
      return { ok: false as const, message: "This staff account has no email address. Contact another super administrator." };
    }

    const credentials = { email: session.user.email, password: parsed.data.password };
    const { error: passwordError } = await withTimeout(
      session.supabase.auth.signInWithPassword(credentials),
    );
    if (passwordError) return { ok: false as const, message: "That password was not accepted." };

    // Supabase requires AAL2 to remove a verified factor. A staff member can
    // reset only their own factor after proving possession of their password.
    const adminClient = createAdminClient();
    const { error: removeError } = await withTimeout(
      adminClient.auth.admin.mfa.deleteFactor({
        id: parsed.data.factorId,
        userId: session.user.id,
      }),
    );
    if (removeError) {
      return { ok: false as const, message: "The existing authenticator could not be replaced. Please try again." };
    }

    const { error: renewedSessionError } = await withTimeout(
      session.supabase.auth.signInWithPassword(credentials),
    );
    if (renewedSessionError) {
      return { ok: false as const, message: "Your security session could not be renewed. Please sign in again." };
    }

    const { data, error: enrollError } = await withTimeout(
      session.supabase.auth.mfa.enroll({
        factorType: "totp",
        friendlyName: "Silarah Admin",
      }),
    );
    if (enrollError || !data) {
      return { ok: false as const, message: "A new authenticator could not be started. Please try again." };
    }

    return {
      ok: true as const,
      userId: session.user.id,
      factorId: data.id,
      uri: data.totp.uri,
    };
  } catch {
    return { ok: false as const, message: "The security service did not respond. Please try again." };
  }
}

const verificationSchema = z.object({
  factorId: z.string().uuid(),
  code: z.string().regex(/^\d{6}$/),
});

async function verifyAuthenticator(input: { factorId: string; code: string }) {
  const parsed = verificationSchema.safeParse(input);
  if (!parsed.success) return { ok: false as const, message: "Enter the current six-digit authenticator code." };

  try {
    const session = await getAuthenticatedClient();
    if ("error" in session) return { ok: false as const, message: session.error };

    const { data: challenge, error: challengeError } = await withTimeout(
      session.supabase.auth.mfa.challenge({ factorId: parsed.data.factorId }),
    );
    if (challengeError || !challenge) {
      return { ok: false as const, message: "Could not verify your authenticator. Please try again." };
    }

    const { error } = await withTimeout(
      session.supabase.auth.mfa.verify({
        factorId: parsed.data.factorId,
        challengeId: challenge.id,
        code: parsed.data.code,
      }),
    );
    if (error) {
      return { ok: false as const, message: "That code was not accepted. Check your authenticator and try again." };
    }

    const { data: assurance, error: assuranceError } = await withTimeout(
      session.supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
    );
    if (assuranceError || assurance?.currentLevel !== "aal2") {
      return { ok: false as const, message: "Your code was accepted, but the secure session was not ready. Please enter a fresh code." };
    }

    return { ok: true as const };
  } catch {
    return { ok: false as const, message: "The security service did not respond. Please enter a fresh code and try again." };
  }
}

function redirectWithError(code: string): never {
  redirect(`/mfa?error=${code}`);
}

export async function enrollAuthenticatorForm() {
  const result = await enrollAuthenticator();
  if (!result.ok) redirectWithError("setup");

  await setPendingMfaFactor(result.userId, {
    factorId: result.factorId,
    uri: result.uri,
  });
  redirect("/mfa");
}

export async function replaceAuthenticatorForm(formData: FormData) {
  const result = await replaceAuthenticator({
    factorId: String(formData.get("factorId") ?? ""),
    password: String(formData.get("password") ?? ""),
  });
  if (!result.ok) redirectWithError("replace");

  await setPendingMfaFactor(result.userId, {
    factorId: result.factorId,
    uri: result.uri,
  });
  redirect("/mfa");
}

export async function verifyAuthenticatorForm(formData: FormData) {
  const result = await verifyAuthenticator({
    factorId: String(formData.get("factorId") ?? ""),
    code: String(formData.get("code") ?? "").replace(/\D/g, "").slice(0, 6),
  });
  if (!result.ok) redirectWithError("verify");

  await clearPendingMfaFactor();
  redirect("/dashboard");
}
