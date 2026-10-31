package com.silarah.admin

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

/**
 * Silarah Admin: the staff console at admin.silarah.com in its own app.
 *
 * The site keeps its own sign-in, MFA and permission checks, so this shell
 * adds no credentials or API access of its own. It only keeps navigation on
 * the admin host, hides staff screens from screenshots and the app switcher
 * (they show member data), and offers a retry when the network drops.
 */
class MainActivity : Activity() {

    private lateinit var webView: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        webView = WebView(this).apply {
            setBackgroundColor(Color.parseColor("#F7F3EA"))
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            settings.setSupportMultipleWindows(false)
            settings.safeBrowsingEnabled = true
            settings.userAgentString = "${settings.userAgentString} SilarahAdminApp/1"
            webViewClient = AdminClient()
        }
        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            setAcceptThirdPartyCookies(webView, false)
        }

        // Android 15+ draws apps edge to edge; keep the console clear of the
        // status and navigation bars.
        val root = FrameLayout(this).apply {
            addView(
                webView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            setOnApplyWindowInsetsListener { view, insets ->
                val bars = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    insets.getInsets(WindowInsets.Type.systemBars())
                } else {
                    @Suppress("DEPRECATION")
                    android.graphics.Insets.of(
                        insets.systemWindowInsetLeft,
                        insets.systemWindowInsetTop,
                        insets.systemWindowInsetRight,
                        insets.systemWindowInsetBottom,
                    )
                }
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                insets
            }
        }
        setContentView(root)

        if (savedInstanceState == null || webView.restoreState(savedInstanceState) == null) {
            webView.loadUrl(HOME)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    @Deprecated("Activity back handling for API 26-32")
    override fun onBackPressed() {
        if (webView.canGoBack()) webView.goBack() else super.onBackPressed()
    }

    override fun onPause() {
        super.onPause()
        CookieManager.getInstance().flush()
    }

    override fun onDestroy() {
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
        super.onDestroy()
    }

    private inner class AdminClient : WebViewClient() {
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            val uri = request.url
            if (uri.scheme == "https" && uri.host == HOST) return false
            if (uri.scheme == "retry") {
                view.loadUrl(HOME)
                return true
            }
            // Anything else (help pages, email links) opens outside the console.
            try {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
            } catch (_: ActivityNotFoundException) {
            }
            return true
        }

        override fun onReceivedError(
            view: WebView,
            request: WebResourceRequest,
            error: WebResourceError,
        ) {
            if (request.isForMainFrame) {
                view.loadDataWithBaseURL(null, OFFLINE_PAGE, "text/html", "utf-8", null)
            }
        }
    }

    companion object {
        private const val HOST = "admin.silarah.com"
        private const val HOME = "https://$HOST/dashboard"

        private val OFFLINE_PAGE = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
            background:#F7F3EA;color:#1E2B26;font-family:sans-serif;text-align:center;padding:24px}
            a{display:inline-block;margin-top:18px;padding:12px 22px;border-radius:999px;background:#175C45;
            color:#fff;text-decoration:none;font-weight:600}</style></head>
            <body><div><h2>Can't reach the admin console</h2>
            <p>Check the connection, then try again.</p><a href="retry://home">Try again</a></div></body></html>
        """.trimIndent()
    }
}
