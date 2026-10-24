import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { headers } from "next/headers";
import "./globals.css";

const inter = localFont({
  src: "./fonts/Inter.woff2",
  variable: "--font-inter",
  weight: "100 900",
  display: "swap",
});
const playfair = localFont({
  src: "./fonts/PlayfairDisplay.woff2",
  variable: "--font-playfair",
  weight: "400 900",
  display: "swap",
});

export const metadata: Metadata = {
  title: { default: "Silarah Operations", template: "%s · Silarah Operations" },
  description: "Silarah Matrimony staff operations.",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#f7f3ea",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Reading the request headers keeps every document dynamic, so each one
  // carries the per-request CSP nonce that Next stamps on its scripts.
  await headers();
  return (
    <html lang="en-IN" className={`${inter.variable} ${playfair.variable}`}>
      <body>{children}</body>
    </html>
  );
}
