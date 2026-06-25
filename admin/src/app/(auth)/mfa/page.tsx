import { requireStaffSession } from "@/lib/auth";
import { MfaEnrollment } from "@/components/mfa-enrollment";
import { getPendingMfaFactor, getVerifiedMfaFactorId } from "./actions";

type MfaPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function MfaPage({ searchParams }: MfaPageProps) {
  const admin = await requireStaffSession();
  const initialFactorId = await getVerifiedMfaFactorId();
  const pendingFactor = await getPendingMfaFactor(admin.id);
  const params = await searchParams;
  return (
    <main className="auth-page">
      <MfaEnrollment
        initialFactorId={initialFactorId}
        pendingFactor={pendingFactor}
        error={params.error}
      />
    </main>
  );
}
