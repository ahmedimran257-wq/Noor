"use client";

import { useState } from "react";
import type { CampaignCountry } from "@/lib/operations";

// The country picker appears only for one-country campaigns, so a stray value
// can never be sent with another audience. Countries with reachable members
// come first, each showing how many members the campaign would reach.
export function CampaignAudience({
  audiences,
  countries,
}: {
  audiences: Record<string, string>;
  countries: CampaignCountry[];
}) {
  const [audience, setAudience] = useState("all");
  const reachable = countries.filter((country) => Number(country.members) > 0);
  const others = countries
    .filter((country) => Number(country.members) === 0)
    .sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="form-grid">
      <label className="field">Audience
        <select name="audience" className="select" value={audience} onChange={(event) => setAudience(event.currentTarget.value)}>
          {Object.entries(audiences).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </label>
      {audience === "country" ? (
        <label className="field">Country
          <select name="countryCode" className="select" required defaultValue={reachable[0]?.iso_code ?? ""}>
            <option value="" disabled>Choose a country</option>
            {reachable.length > 0 ? (
              <optgroup label="Members can be reached">
                {reachable.map((country) => (
                  <option key={country.iso_code} value={country.iso_code}>
                    {country.name} · {Number(country.members).toLocaleString("en-IN")} {Number(country.members) === 1 ? "member" : "members"}
                  </option>
                ))}
              </optgroup>
            ) : null}
            <optgroup label="No visible members yet">
              {others.map((country) => <option key={country.iso_code} value={country.iso_code}>{country.name}</option>)}
            </optgroup>
          </select>
          <small>Visible, active members whose profile is in this country.</small>
        </label>
      ) : (
        <div className="field" aria-hidden="true">
          <span>&nbsp;</span>
          <small>Choose “One country” to target a single country.</small>
        </div>
      )}
    </div>
  );
}
