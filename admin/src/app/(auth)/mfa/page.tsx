import { redirect } from "next/navigation";
import { requireStaffSession } from "@/lib/auth";
import { MfaEnrollment } from "@/components/mfa-enrollment";
import { getPendingMfaFactor, getVerifiedMfaFactorId } from "./actions";

export const metadata = { title: "Security check" };

type MfaPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function MfaPage({ searchParams }: MfaPageProps) {
  const admin = await requireStaffSession();
  const params = await searchParams;
  const pendingFactor = await getPendingMfaFactor(admin.id);
  // Already verified in this session: nothing to do here.
  if (admin.aal === "aal2" && admin.hasVerifiedTotp && !pendingFactor && !params.error) redirect("/dashboard");
  // Skip the factor lookup when the context already says none is verified.
  const initialFactorId = admin.hasVerifiedTotp ? await getVerifiedMfaFactorId() : undefined;
  return (
    <main className="auth">
      <MfaEnrollment
        initialFactorId={initialFactorId}
        pendingFactor={pendingFactor}
        error={params.error}
      />
    </main>
  );
}
