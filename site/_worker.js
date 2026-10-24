// Silarah public site worker.
//
// Serves the static site and personalises HTML at the edge using Cloudflare's
// visitor geolocation, without client-side scripts (the CSP stays strict):
// - India: the home page names the visitor's state.
// - Outside India: a notice explains that Silarah is open only in India.
// - Hindi or Urdu browsers on the English home page are offered their language.
// Crawlers always receive the unpersonalised page.

const LANGS = ['en', 'hi', 'ur'];

// ISO 3166-2:IN subdivision codes (old and new forms) → [English, Hindi, Urdu].
const STATES = {
  AN: ['Andaman and Nicobar Islands', 'अंडमान और निकोबार द्वीपसमूह', 'جزائر انڈمان و نکوبار'],
  AP: ['Andhra Pradesh', 'आंध्र प्रदेश', 'آندھرا پردیش'],
  AR: ['Arunachal Pradesh', 'अरुणाचल प्रदेश', 'اروناچل پردیش'],
  AS: ['Assam', 'असम', 'آسام'],
  BR: ['Bihar', 'बिहार', 'بہار'],
  CH: ['Chandigarh', 'चंडीगढ़', 'چندی گڑھ'],
  CT: ['Chhattisgarh', 'छत्तीसगढ़', 'چھتیس گڑھ'],
  CG: ['Chhattisgarh', 'छत्तीसगढ़', 'چھتیس گڑھ'],
  DH: ['Dadra and Nagar Haveli and Daman and Diu', 'दादरा और नगर हवेली और दमन और दीव', 'دادرا و نگر حویلی اور دمن و دیو'],
  DN: ['Dadra and Nagar Haveli and Daman and Diu', 'दादरा और नगर हवेली और दमन और दीव', 'دادرا و نگر حویلی اور دمن و دیو'],
  DD: ['Dadra and Nagar Haveli and Daman and Diu', 'दादरा और नगर हवेली और दमन और दीव', 'دادرا و نگر حویلی اور دمن و دیو'],
  DL: ['Delhi', 'दिल्ली', 'دہلی'],
  GA: ['Goa', 'गोवा', 'گوا'],
  GJ: ['Gujarat', 'गुजरात', 'گجرات'],
  HR: ['Haryana', 'हरियाणा', 'ہریانہ'],
  HP: ['Himachal Pradesh', 'हिमाचल प्रदेश', 'ہماچل پردیش'],
  JK: ['Jammu and Kashmir', 'जम्मू और कश्मीर', 'جموں و کشمیر'],
  JH: ['Jharkhand', 'झारखंड', 'جھارکھنڈ'],
  KA: ['Karnataka', 'कर्नाटक', 'کرناٹک'],
  KL: ['Kerala', 'केरल', 'کیرالہ'],
  LA: ['Ladakh', 'लद्दाख', 'لداخ'],
  LD: ['Lakshadweep', 'लक्षद्वीप', 'لکشدیپ'],
  MP: ['Madhya Pradesh', 'मध्य प्रदेश', 'مدھیہ پردیش'],
  MH: ['Maharashtra', 'महाराष्ट्र', 'مہاراشٹر'],
  MN: ['Manipur', 'मणिपुर', 'منی پور'],
  ML: ['Meghalaya', 'मेघालय', 'میگھالیہ'],
  MZ: ['Mizoram', 'मिज़ोरम', 'میزورم'],
  NL: ['Nagaland', 'नागालैंड', 'ناگالینڈ'],
  OR: ['Odisha', 'ओडिशा', 'اوڈیشہ'],
  OD: ['Odisha', 'ओडिशा', 'اوڈیشہ'],
  PY: ['Puducherry', 'पुडुचेरी', 'پڈوچیری'],
  PB: ['Punjab', 'पंजाब', 'پنجاب'],
  RJ: ['Rajasthan', 'राजस्थान', 'راجستھان'],
  SK: ['Sikkim', 'सिक्किम', 'سکم'],
  TN: ['Tamil Nadu', 'तमिलनाडु', 'تمل ناڈو'],
  TG: ['Telangana', 'तेलंगाना', 'تلنگانہ'],
  TS: ['Telangana', 'तेलंगाना', 'تلنگانہ'],
  TR: ['Tripura', 'त्रिपुरा', 'تریپورہ'],
  UP: ['Uttar Pradesh', 'उत्तर प्रदेश', 'اتر پردیش'],
  UT: ['Uttarakhand', 'उत्तराखंड', 'اتراکھنڈ'],
  UK: ['Uttarakhand', 'उत्तराखंड', 'اتراکھنڈ'],
  WB: ['West Bengal', 'पश्चिम बंगाल', 'مغربی بنگال'],
};

const COPY = {
  en: {
    pill: (state) => `Now welcoming members across ${state}`,
    away: (country) => `Silarah is open only to adults in India for now — it is not yet available in ${country}.`,
    awayFallback: 'Silarah is open only to adults in India for now — it is not yet available where you are.',
    awayLink: 'Why India first',
  },
  hi: {
    pill: (state) => `${state} सहित पूरे भारत में सदस्यों का स्वागत है`,
    away: (country) => `सिलाराह अभी केवल भारत में वयस्कों के लिए उपलब्ध है — ${country} में अभी उपलब्ध नहीं है।`,
    awayFallback: 'सिलाराह अभी केवल भारत में वयस्कों के लिए उपलब्ध है — आपके देश में अभी उपलब्ध नहीं है।',
    awayLink: 'भारत पहले क्यों',
  },
  ur: {
    pill: (state) => `${state} سمیت پورے ہندوستان میں اراکین کا خیرمقدم ہے`,
    away: (country) => `سلارہ فی الحال صرف ہندوستان میں بالغوں کے لیے دستیاب ہے — ${country} میں ابھی دستیاب نہیں۔`,
    awayFallback: 'سلارہ فی الحال صرف ہندوستان میں بالغوں کے لیے دستیاب ہے — آپ کے ملک میں ابھی دستیاب نہیں۔',
    awayLink: 'پہلے ہندوستان کیوں',
  },
};

const OFFER = {
  hi: { text: 'यह पेज हिन्दी में भी उपलब्ध है।', link: 'हिन्दी में देखें', href: '/hi/' },
  ur: { text: 'یہ صفحہ اردو میں بھی دستیاب ہے۔', link: 'اردو میں دیکھیں', href: '/ur/' },
};

const BOT = /bot|crawl|spider|slurp|preview|facebookexternalhit|lighthouse|headless/i;

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

function pageLanguage(pathname) {
  const first = pathname.split('/')[1];
  return LANGS.includes(first) && first !== 'en' ? first : 'en';
}

function preferredOffer(acceptLanguage) {
  for (const part of (acceptLanguage || '').split(',')) {
    const tag = part.split(';')[0].trim().toLowerCase();
    if (tag.startsWith('en')) return null;
    if (tag.startsWith('hi')) return OFFER.hi;
    if (tag.startsWith('ur')) return OFFER.ur;
  }
  return null;
}

function countryName(code, lang) {
  try {
    const name = new Intl.DisplayNames([lang === 'en' ? 'en-IN' : lang], { type: 'region' }).of(code);
    return name && name !== code ? name : null;
  } catch {
    return null;
  }
}

function strip(content, dir) {
  return `<div class="geo-strip" role="note" data-nosnippet${dir ? ` dir="${dir}"` : ''}><div class="shell">${content}</div></div>`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname === 'www.silarah.com') {
      url.hostname = 'silarah.com';
      return Response.redirect(url.toString(), 301);
    }

    const response = await env.ASSETS.fetch(request);
    const type = response.headers.get('content-type') || '';
    if (request.method !== 'GET' || !type.includes('text/html')) return response;
    if (BOT.test(request.headers.get('user-agent') || '')) return response;

    const cf = request.cf || {};
    const country = (cf.country || '').toUpperCase();
    const lang = pageLanguage(url.pathname);
    const copy = COPY[lang];
    const isHome = url.pathname === '/' || url.pathname === `/${lang}/`;

    const notes = [];
    if (country && country !== 'IN' && country !== 'XX' && country !== 'T1') {
      const name = countryName(country, lang);
      notes.push(`<span>${escapeHtml(name ? copy.away(name) : copy.awayFallback)}</span><a href="/#roadmap">${escapeHtml(copy.awayLink)}</a>`);
    }
    if (lang === 'en' && url.pathname === '/') {
      const offer = preferredOffer(request.headers.get('accept-language'));
      if (offer) notes.push(`<span>${escapeHtml(offer.text)}</span><a href="${offer.href}">${escapeHtml(offer.link)}</a>`);
    }

    const state = country === 'IN' ? STATES[(cf.regionCode || '').toUpperCase()] : null;
    const stateName = state ? state[LANGS.indexOf(lang)] : null;

    let rewriter = new HTMLRewriter();
    if (notes.length) {
      const html = strip(notes.join('<i aria-hidden="true">·</i>'), lang === 'ur' ? 'rtl' : '');
      rewriter = rewriter.on('body > header', { element(el) { el.prepend(html, { html: true }); } });
    }
    if (isHome && stateName) {
      rewriter = rewriter.on('[data-geo="pill"]', {
        element(el) { el.setInnerContent(`<span></span> ${escapeHtml(copy.pill(stateName))}`, { html: true }); },
      });
    }

    const personalised = rewriter.transform(response);
    const headers = new Headers(personalised.headers);
    headers.set('Cache-Control', 'private, no-cache');
    headers.append('Vary', 'Accept-Language');
    return new Response(personalised.body, { status: personalised.status, statusText: personalised.statusText, headers });
  },
};
