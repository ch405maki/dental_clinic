import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io'; // For Platform check
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async'; // For Timer
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
      home: OnboardingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: [
          OnboardingPage(
            imagePath: 'assets/images/image1.png',
            title: 'KSU Dental Clinic',
            description:
                'Experience exceptional dental care where your health and satisfaction are our top priority.',
            onNextPressed: () => _pageController.nextPage(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
          OnboardingPage(
            imagePath: 'assets/images/image2.png',
            title: 'Book Your Appointment Online"',
            description:
                'Conveniently schedule your dental visit in just a few clicks.',
            onNextPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DentalClinicWebView()),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final VoidCallback onNextPressed;

  OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.onNextPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(imagePath),
        SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: onNextPressed,
          child: Text('Next'),
        ),
      ],
    );
  }
}

class DentalClinicWebView extends StatefulWidget {
  @override
  _DentalClinicWebViewState createState() => _DentalClinicWebViewState();
}

class _DentalClinicWebViewState extends State<DentalClinicWebView>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isConnected = true;
  bool _isPageAvailable = true;
  bool _isLoading = false;
  Timer? _loadingTimer;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  int _backPressCounter = 0;
  Timer? _backPressTimer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();

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
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            _animationController.repeat();
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _animationController.stop();
            _animationController.reset();
            _injectZoomDisablingScript();
          },
          onHttpError: (HttpResponseError error) {
            _showPageNotAvailable();
          },
          onWebResourceError: (WebResourceError error) {
            if (error.errorType == WebResourceErrorType.connect ||
                error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout ||
                error.errorCode == 404 ||
                error.errorCode == 500) {
              _showPageNotAvailable();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://ksudentalclinic.com/login')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (Platform.isAndroid) {
      // Enable debugging for Android WebView
      AndroidWebViewController.enableDebugging(true);
      // Set additional Android-specific settings if needed
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      _handleConnectivityChange(result);
    });

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _backPressTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    setState(() {
      _isLoading = true;
    });
    var connectivityResult = await (Connectivity().checkConnectivity());
    _handleConnectivityChange(connectivityResult);
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
      });
      _showNoInternetDialog();
    } else {
      setState(() {
        _isConnected = true;
        _isLoading = false;
        _controller.loadRequest(Uri.parse('https://ksudentalclinic.com/login'));
      });
    }
  }

  void _showPageNotAvailable() {
    setState(() {
      _isPageAvailable = false;
      _isLoading = false;
    });
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5.0))),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.yellow),
              SizedBox(width: 10),
              Text("No Internet Connection"),
            ],
          ),
          content: Text("Please check your connection and try again."),
          actions: [
            TextButton(
              child: Text("Refresh"),
              onPressed: () {
                Navigator.of(context).pop();
                _checkInternetConnection();
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _injectZoomDisablingScript() {
    _controller.runJavaScript('''
      var meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      document.getElementsByTagName('head')[0].appendChild(meta);
    ''');
  }

  Future<bool> _onWillPop() async {
    if (_backPressCounter == 0) {
      _backPressCounter++;
      _backPressTimer = Timer(Duration(seconds: 2), () {
        _backPressCounter = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    } else {
      _backPressTimer?.cancel();
      bool shouldExit = await _showExitConfirmationDialog();
      if (shouldExit) {
        return true;
      } else {
        _backPressCounter = 0;
        return false;
      }
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Exit App'),
              content: Text('Are you sure you want to close the app?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Exit'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(0.0), // Set the height of the AppBar
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0.0, // Set the elevation
            title: Text(''),
          ),
        ),
        body: Stack(
          children: [
            Visibility(
              visible: _isPageAvailable,
              child: WebViewWidget(controller: _controller),
            ),
            Visibility(
              visible: !_isPageAvailable,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.yellow, size: 100),
                    SizedBox(height: 20),
                    Text(
                      'Page Not Available',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Please check your connection or try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 20),
                    _isLoading
                        ? SpinKitCircle(
                            color: Colors.green,
                            size: 50.0,
                          )
                        : ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isPageAvailable = true;
                                _isLoading = true;
                              });
                              _checkInternetConnection();
                            },
                            child: Text('Retry'),
                          ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpinKitCircle(
                        color: Colors.green,
                        size: 50.0,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Loading...',
                        style: TextStyle(fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _isLoading = true;
            });
            _controller.reload();
            _animationController.repeat();
          },
          child: RotationTransition(
            turns: _animationController,
            child: Icon(Icons.refresh),
          ),
          backgroundColor: Colors.green,
        ),
      ),
    );
  }
}
