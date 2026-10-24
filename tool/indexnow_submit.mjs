// Submits every URL in the live sitemap to IndexNow (Bing, Yandex, Seznam,
// Naver and other participating engines) so changes are crawled promptly.
//
// Run after deploying the public site:  node tool/indexnow_submit.mjs
// The key file is served at https://silarah.com/<key>.txt to prove ownership.

const HOST = 'silarah.com';
const KEY = '9d3674d6df8046fe7197fb5dbadc8501';

const sitemap = await (await fetch(`https://${HOST}/sitemap.xml`)).text();
const urlList = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
if (urlList.length === 0) throw new Error('No URLs found in the live sitemap.');

const keyCheck = await fetch(`https://${HOST}/${KEY}.txt`);
if (!keyCheck.ok || (await keyCheck.text()).trim() !== KEY) {
  throw new Error('The IndexNow key file is not live yet; deploy the site first.');
}

const response = await fetch('https://api.indexnow.org/indexnow', {
  method: 'POST',
  headers: { 'content-type': 'application/json; charset=utf-8' },
  body: JSON.stringify({ host: HOST, key: KEY, keyLocation: `https://${HOST}/${KEY}.txt`, urlList }),
});
console.log(`IndexNow: ${response.status} ${response.statusText} for ${urlList.length} URLs`);
if (response.status >= 400) process.exitCode = 1;
