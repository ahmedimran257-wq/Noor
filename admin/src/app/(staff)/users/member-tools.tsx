"use client";

import { Eye, EyeOff } from "lucide-react";
import { useActionState, useState } from "react";
import { revealUserPii, type RevealState } from "../actions";
import { SubmitButton } from "@/components/client-ui";

const reasons = [
  "Member support request",
  "Safety investigation",
  "Legal or privacy request",
  "Account recovery",
];

// Masked by default. A reveal is a deliberate, reasoned, audited POST that
// only updates this row; the rest of the table never re-renders.
export function MemberIdentity({
  userId,
  maskedName,
  maskedEmail,
  canReveal,
}: {
  userId: string;
  maskedName: string;
  maskedEmail: string | null;
  canReveal: boolean;
}) {
  const [state, action] = useActionState<RevealState, FormData>(revealUserPii, { status: "idle" });
  const [asking, setAsking] = useState(false);
  const [hidden, setHidden] = useState(false);
  const revealed = state.status === "revealed" && !hidden;

  return (
    <div>
      <span className="cell-main">{revealed ? state.name || "Unnamed" : maskedName}</span>
      <span className="cell-sub">{revealed ? state.email ?? "No email" : maskedEmail ?? userId}</span>
      {revealed ? (
        <button type="button" className="text-button" onClick={() => setHidden(true)}>
          <span className="row"><EyeOff size={13} /> Hide · reveal was audited</span>
        </button>
      ) : canReveal ? (
        asking ? (
          <form
            action={(formData) => {
              setHidden(false);
              setAsking(false);
              action(formData);
            }}
            className="row"
          >
            <input type="hidden" name="userId" value={userId} />
            <label className="sr-only" htmlFor={`reason-${userId}`}>Reason for revealing</label>
            <select id={`reason-${userId}`} name="reason" className="select btn-sm" required defaultValue="">
              <option value="" disabled>Why do you need this?</option>
              {reasons.map((reason) => <option key={reason}>{reason}</option>)}
            </select>
            <SubmitButton className="btn btn-sm">Reveal</SubmitButton>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setAsking(false)}>Cancel</button>
          </form>
        ) : (
          <button type="button" className="text-button" onClick={() => setAsking(true)}>
            <span className="row"><Eye size={13} /> Reveal identity</span>
          </button>
        )
      ) : null}
      {state.status === "error" ? <span className="cell-sub" role="alert">{state.message}</span> : null}
    </div>
  );
}

export function SelectAll({ formId }: { formId: string }) {
  return (
    <input
      type="checkbox"
      aria-label="Select all members on this page"
      onChange={(event) => {
        const checked = event.currentTarget.checked;
        document
          .querySelectorAll<HTMLInputElement>(`input[type=checkbox][form="${formId}"][name="userIds"]`)
          .forEach((box) => { box.checked = checked; });
      }}
    />
  );
}
