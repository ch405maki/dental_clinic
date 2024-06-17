import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io'; // For Platform check

void main() {
  // Lock the orientation to portrait mode
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dental Clinic',
      home: DentalClinicWebView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DentalClinicWebView extends StatefulWidget {
  @override
  _DentalClinicWebViewState createState() => _DentalClinicWebViewState();
}

class _DentalClinicWebViewState extends State<DentalClinicWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            // Inject JavaScript to disable zooming
            _controller.runJavaScript(
              "document.querySelector('meta[name=\"viewport\"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');"
            );
          },
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://mapa-recordmanagementsystem.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://mapa-recordmanagementsystem.com/'));

    if (Platform.isAndroid) {
      // Enable debugging for Android WebView
      AndroidWebViewController.enableDebugging(true);
      // Set additional Android-specific settings if needed
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0.0), // Set the height of the AppBar
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 10.0, // Set the elevation
          title: Text(''),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}