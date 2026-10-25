// Shared Silarah email shell: Ivory & Emerald, table-based for Outlook,
// web-font serif with Georgia fallbacks, and explicit dark-mode overrides for
// Apple Mail and Outlook.com. Gmail ignores prefers-color-scheme and applies
// its own inversion, so the light palette is chosen to invert cleanly.

export const BRAND = {
  canvas: "#F7F3EA",
  surface: "#FFFDF8",
  sunk: "#FBF8F1",
  line: "#E7DFCF",
  lineStrong: "#D8CCB5",
  ink: "#1B2A23",
  inkSoft: "#3D4A43",
  muted: "#6F7469",
  emerald: "#175C45",
  emeraldDeep: "#0F4433",
  emeraldSoft: "#E4EFE8",
  champagne: "#B08D57",
  champagneSoft: "#F4ECDD",
  danger: "#A3402C",
  dangerSoft: "#F8E7E1",
} as const;

const SERIF =
  "'Playfair Display','Iowan Old Style','Palatino Linotype',Palatino,Georgia,'Times New Roman',serif";
const SANS =
  "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif";
const MONO = "'SFMono-Regular',Menlo,Consolas,'Liberation Mono',monospace";

export const HELP_URL = "https://silarah.com/help/";
export const PRIVACY_URL = "https://silarah.com/privacy/";
export const TERMS_URL = "https://silarah.com/terms/";
export const SUPPORT_EMAIL = "support@silarah.com";

export interface EmailLayoutInput {
  title: string;
  preheader: string;
  eyebrow: string;
  heading: string;
  /** Pre-rendered, already-escaped HTML blocks placed inside the card. */
  body: string;
  /** Short, already-escaped line shown under the card, e.g. why it was sent. */
  reason: string;
  tone?: "standard" | "attention";
}

export function renderEmailLayout(input: EmailLayoutInput): string {
  const eyebrowColor = input.tone === "attention"
    ? BRAND.danger
    : BRAND.champagne;
  return `<!doctype html>
<html lang="en" dir="ltr" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="x-apple-disable-message-reformatting">
<meta name="format-detection" content="telephone=no,date=no,address=no,email=no,url=no">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>${input.title}</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
<!--[if mso]><style>.serif{font-family:Georgia,'Times New Roman',serif !important;}td,p,a,span,div{font-family:'Segoe UI',Arial,sans-serif;}</style><![endif]-->
<style>
@font-face{font-family:'Playfair Display';font-style:normal;font-weight:400 700;font-display:swap;src:url('https://silarah.com/assets/fonts/PlayfairDisplay.woff2') format('woff2');}
:root{color-scheme:light dark;supported-color-schemes:light dark;}
body{margin:0 !important;padding:0 !important;width:100% !important;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;}
a[x-apple-data-detectors]{color:inherit !important;text-decoration:none !important;}
u + #body a{color:inherit;text-decoration:none;}
@media only screen and (max-width:620px){
.shell{padding:28px 12px 32px !important;}
.px{padding-left:26px !important;padding-right:26px !important;}
.h1{font-size:27px !important;line-height:35px !important;}
.code{font-size:32px !important;letter-spacing:9px !important;}
}
@media (prefers-color-scheme:dark){
.bg{background:#0F1713 !important;}
.card{background:#16211B !important;border-color:#2A3830 !important;}
.sunk{background:#1C2922 !important;border-color:#33453A !important;}
.rule{border-color:#2A3830 !important;}
.ink{color:#F3EEE3 !important;}
.soft{color:#D3D8D0 !important;}
.muted{color:#A2AA9F !important;}
.brand{color:#9FD3BA !important;}
.gold{color:#D2B27C !important;}
.alert{color:#F0A18D !important;}
.goldbar{background:#B08D57 !important;}
.btn{background:#2C8463 !important;}
.btn-a{color:#FFFFFF !important;}
.link{color:#9FD3BA !important;}
}
[data-ogsc] .ink{color:#F3EEE3 !important;}
[data-ogsc] .soft{color:#D3D8D0 !important;}
[data-ogsc] .muted{color:#A2AA9F !important;}
[data-ogsc] .brand,[data-ogsc] .link{color:#9FD3BA !important;}
[data-ogsc] .gold{color:#D2B27C !important;}
[data-ogsc] .alert{color:#F0A18D !important;}
[data-ogsb] .bg{background:#0F1713 !important;}
[data-ogsb] .card{background:#16211B !important;}
[data-ogsb] .sunk{background:#1C2922 !important;}
[data-ogsb] .btn{background:#2C8463 !important;}
</style>
</head>
<body id="body" class="bg" style="margin:0;padding:0;background:${BRAND.canvas};">
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">${input.preheader}&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" class="bg" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background:${BRAND.canvas};">
<tr><td class="shell" align="center" style="padding:44px 16px 40px;">
<!--[if mso]><table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0"><tr><td><![endif]-->
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;">
<tr><td align="center" style="padding:0 8px 26px;">
<div class="serif brand" style="font-family:${SERIF};font-size:30px;line-height:36px;font-weight:600;letter-spacing:0.4px;color:${BRAND.emerald};">Silarah</div>
<div class="gold" style="padding-top:6px;font-family:${SANS};font-size:10px;line-height:16px;font-weight:600;letter-spacing:2.6px;text-transform:uppercase;color:${BRAND.champagne};">Introductions with intention</div>
</td></tr>
<tr><td class="card" style="background:${BRAND.surface};border:1px solid ${BRAND.line};border-radius:16px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
<tr><td align="center" style="padding:0 44px;"><table role="presentation" width="56" cellspacing="0" cellpadding="0" border="0"><tr><td class="goldbar" height="2" style="height:2px;width:56px;background:${BRAND.champagne};font-size:0;line-height:0;">&nbsp;</td></tr></table></td></tr>
<tr><td class="px" style="padding:36px 48px 8px;">
<div class="${
    input.tone === "attention" ? "alert" : "gold"
  }" style="font-family:${SANS};font-size:11px;line-height:16px;font-weight:600;letter-spacing:1.8px;text-transform:uppercase;color:${eyebrowColor};">${input.eyebrow}</div>
<h1 class="serif ink h1" style="margin:12px 0 0;font-family:${SERIF};font-size:31px;line-height:39px;font-weight:500;letter-spacing:-0.2px;color:${BRAND.ink};mso-line-height-rule:exactly;">${input.heading}</h1>
</td></tr>
${input.body}
</table>
</td></tr>
<tr><td style="padding:26px 24px 0;text-align:center;">
<p class="muted" style="margin:0 0 12px;font-family:${SANS};font-size:12px;line-height:19px;color:${BRAND.muted};">${input.reason}</p>
<p class="muted" style="margin:0;font-family:${SANS};font-size:12px;line-height:19px;color:${BRAND.muted};"><a class="link" href="${HELP_URL}" style="color:${BRAND.emerald};text-decoration:underline;">Help centre</a>&nbsp;&nbsp;&middot;&nbsp;&nbsp;<a class="link" href="${PRIVACY_URL}" style="color:${BRAND.emerald};text-decoration:underline;">Privacy</a>&nbsp;&nbsp;&middot;&nbsp;&nbsp;<a class="link" href="${TERMS_URL}" style="color:${BRAND.emerald};text-decoration:underline;">Terms</a></p>
<p class="muted" style="margin:14px 0 0;font-family:${SANS};font-size:11px;line-height:17px;color:${BRAND.muted};">Silarah &middot; Private matrimonial introductions, made in India</p>
</td></tr>
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr>
</table>
</body>
</html>
`;
}

export function paragraph(html: string, options: { last?: boolean } = {}) {
  return `<tr><td class="px" style="padding:${
    options.last ? "14px 48px 6px" : "14px 48px 0"
  };"><p class="soft" style="margin:0;font-family:${SANS};font-size:16px;line-height:26px;color:${BRAND.inkSoft};">${html}</p></td></tr>`;
}

export function greeting(html: string) {
  return `<tr><td class="px" style="padding:20px 48px 0;"><p class="ink" style="margin:0;font-family:${SANS};font-size:16px;line-height:26px;color:${BRAND.ink};">${html}</p></td></tr>`;
}

/** Highlighted status or code panel on the sunk ivory surface. */
export function panel(label: string, value: string, options: {
  mono?: boolean;
  tone?: "standard" | "attention";
} = {}) {
  const valueStyle = options.mono
    ? `font-family:${MONO};font-size:38px;line-height:46px;font-weight:600;letter-spacing:12px;color:${BRAND.emeraldDeep};white-space:nowrap;`
    : `font-family:${SERIF};font-size:22px;line-height:30px;font-weight:500;color:${
      options.tone === "attention" ? BRAND.danger : BRAND.emeraldDeep
    };`;
  const valueClass = options.mono
    ? "brand code"
    : options.tone === "attention"
    ? "serif alert"
    : "serif brand";
  return `<tr><td class="px" style="padding:26px 48px 4px;">
<table role="presentation" class="sunk" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:${BRAND.sunk};border:1px solid ${BRAND.lineStrong};border-radius:12px;">
<tr><td align="${options.mono ? "center" : "left"}" style="padding:${
    options.mono ? "22px 12px 24px" : "18px 22px 20px"
  };">
<div class="muted" style="font-family:${SANS};font-size:11px;line-height:16px;font-weight:600;letter-spacing:1.4px;text-transform:uppercase;color:${BRAND.muted};">${label}</div>
<div class="${valueClass}" style="padding-top:${
    options.mono ? "10px" : "6px"
  };${valueStyle}">${value}</div>
</td></tr>
</table>
</td></tr>`;
}

/** Two-column label/value list separated by hairlines. */
export function detailList(title: string, rows: [string, string][]) {
  const body = rows.map(([label, value], index) => {
    const border = index === rows.length - 1
      ? ""
      : `border-bottom:1px solid ${BRAND.line};`;
    return `<tr>
<td class="muted rule" valign="top" style="padding:11px 12px 11px 0;${border}font-family:${SANS};font-size:14px;line-height:21px;color:${BRAND.muted};">${label}</td>
<td class="ink rule" align="right" valign="top" style="padding:11px 0;${border}font-family:${SANS};font-size:14px;line-height:21px;font-weight:600;color:${BRAND.ink};">${value}</td>
</tr>`;
  }).join("\n");
  return `<tr><td class="px" style="padding:26px 48px 0;">
<div class="gold" style="padding-bottom:4px;font-family:${SANS};font-size:11px;line-height:16px;font-weight:600;letter-spacing:1.4px;text-transform:uppercase;color:${BRAND.champagne};">${title}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
${body}
</table>
</td></tr>`;
}

/** Short numbered or bulleted list of next steps. */
export function steps(title: string, items: [string, string][]) {
  const rows = items.map(([heading, copy], index) =>
    `<tr>
<td width="34" valign="top" style="padding:${
      index === 0 ? "2px" : "16px"
    } 0 0;"><div class="gold" style="width:24px;height:24px;border:1px solid ${BRAND.champagne};border-radius:12px;text-align:center;font-family:${SERIF};font-size:13px;line-height:24px;color:${BRAND.champagne};">${
      index + 1
    }</div></td>
<td valign="top" style="padding:${
      index === 0 ? "0" : "14px"
    } 0 0 8px;font-family:${SANS};font-size:14px;line-height:22px;"><strong class="ink" style="display:block;font-weight:600;color:${BRAND.ink};">${heading}</strong><span class="muted" style="color:${BRAND.muted};">${copy}</span></td>
</tr>`
  ).join("\n");
  return `<tr><td class="px" style="padding:28px 48px 0;">
<div class="gold" style="padding-bottom:12px;font-family:${SANS};font-size:11px;line-height:16px;font-weight:600;letter-spacing:1.4px;text-transform:uppercase;color:${BRAND.champagne};">${title}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
${rows}
</table>
</td></tr>`;
}

/** Bulletproof button: VML for Outlook desktop, padded link elsewhere. */
export function button(label: string, href: string) {
  return `<tr><td class="px" align="center" style="padding:30px 48px 4px;">
<!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="${href}" style="height:50px;v-text-anchor:middle;width:504px;" arcsize="22%" stroke="f" fillcolor="${BRAND.emerald}"><w:anchorlock/><center style="color:#FFFDF8;font-family:'Segoe UI',Arial,sans-serif;font-size:15px;font-weight:600;">${label}</center></v:roundrect><![endif]-->
<!--[if !mso]><!--><table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"><tr><td class="btn" align="center" style="border-radius:11px;background:${BRAND.emerald};"><a class="btn-a" href="${href}" style="display:block;padding:15px 20px;font-family:${SANS};font-size:15px;line-height:20px;font-weight:600;color:#FFFDF8;text-decoration:none;border-radius:11px;">${label}</a></td></tr></table><!--<![endif]-->
</td></tr>`;
}

/** Quiet closing note inside the card, on a sunk band. */
export function note(html: string) {
  return `<tr><td class="px" style="padding:26px 48px 0;"><p class="muted" style="margin:0;font-family:${SANS};font-size:13px;line-height:21px;color:${BRAND.muted};">${html}</p></td></tr>`;
}

export function signOff(html: string) {
  return `<tr><td class="px" style="padding:26px 48px 0;"><p class="soft" style="margin:0;font-family:${SANS};font-size:15px;line-height:24px;color:${BRAND.inkSoft};">${html}</p></td></tr>
<tr><td style="padding:34px 0 0;font-size:0;line-height:0;">&nbsp;</td></tr>`;
}

export function footerBand(html: string) {
  return `<tr><td class="px sunk rule" style="padding:18px 48px 20px;background:${BRAND.sunk};border-top:1px solid ${BRAND.line};border-radius:0 0 16px 16px;"><p class="muted" style="margin:0;font-family:${SANS};font-size:13px;line-height:20px;color:${BRAND.muted};">${html}</p></td></tr>`;
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
