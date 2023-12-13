//
//  WebViewDelegate.swift
//  app_components
//
//  Created by wli on 27/11/23.
//

import SwiftUI
import Combine
import WebKit

// MARK: - WebViewHandlerDelegate

struct CognitoKeys {
    let user_pool_domain = "<your_user_pool_domain>"
    let redirect_uri = "<your_redirect_uri>"
    let client_id = "<your_user_pool_client_id>"
    let client_secret = "<your_user_pool_client_secret>"
    let app_scope =  "<your_app_scope>" // eg: "aws.cognito.signin.user.admin+email+openid+phone+profile"
}

// MARK: - WebView
struct App_WebView: UIViewRepresentable {
    
    var loadingUrl: String
    // Viewmodel object
    @ObservedObject var viewModel: WebViewModel
    
    // Make a coordinator to co-ordinate with WKWebView's default delegate functions
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Enable javascript in WKWebView
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        // Here "iOSNative" is our delegate name that we pushed to the website that is being loaded
        configuration.userContentController.add(self.makeCoordinator(), name: "iOSNative")
        configuration.defaultWebpagePreferences = preferences
        configuration.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieStore.delete(cookie, completionHandler: nil)
            }
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: loadingUrl) {
            webView.load(URLRequest(url: url))
            
            webView.customUserAgent = "'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) ' 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36'"
        }
    }
    
    class Coordinator : NSObject, WKNavigationDelegate {
        var parent: App_WebView
        var valueSubscriber: AnyCancellable? = nil
        var webViewNavigationSubscriber: AnyCancellable? = nil
        
        init(_ uiWebView: App_WebView) {
            self.parent = uiWebView
        }
        
        deinit {
            valueSubscriber?.cancel()
            webViewNavigationSubscriber?.cancel()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Get the title of loaded webcontent
            webView.evaluateJavaScript("document.title") { (response, error) in
                if let error = error {
                    print("Error getting title")
                    print(error.localizedDescription)
                    self.parent.viewModel.webError.send(error.localizedDescription)
                }
                
                guard let title = response as? String else {
                    return
                }
                
                self.parent.viewModel.webViewTitle.send(title)
            }
            
            /* An observer that observes 'viewModel.valuePublisher' to get value from TextField and
             pass that value to web app by calling JavaScript function */
            valueSubscriber = parent.viewModel.valuePublisher.receive(on: RunLoop.main).sink(receiveValue: { value in
                let javascriptFunction = "valueGotFromIOS(\(value));"
                webView.evaluateJavaScript(javascriptFunction) { (response, error) in
                    if let error = error {
                        print("Error calling javascript:valueGotFromIOS()")
                        print(error.localizedDescription)
                    } else {
                        print("Called javascript:valueGotFromIOS()")
                    }
                }
            })
            
            // Page loaded so no need to show loader anymore
            self.parent.viewModel.showLoader.send(false)
        }
        
        /* Here I implemented most of the WKWebView's delegate functions so that you can know them and
         can use them in different necessary purposes */
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Hides loader
            parent.viewModel.showLoader.send(false)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Hides loader
            self.parent.viewModel.webError.send(error.localizedDescription)
            parent.viewModel.showLoader.send(false)
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Shows loader
            parent.viewModel.showLoader.send(true)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Shows loader
            parent.viewModel.showLoader.send(true)
            self.webViewNavigationSubscriber = self.parent.viewModel.webViewNavigationPublisher.receive(on: RunLoop.main).sink(receiveValue: { navigation in
                switch navigation {
                case .backward:
                    if webView.canGoBack {
                        webView.goBack()
                    }
                case .forward:
                    if webView.canGoForward {
                        webView.goForward()
                    }
                case .reload:
                    webView.reload()
                }
            })
        }
        
        // This function is essential for intercepting every navigation in the webview
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Suppose you don't want your user to go a restricted site
            // Here you can get many information about new url from 'navigationAction.request.description'
            
            if let urlStr = navigationAction.request.url?.absoluteString,  urlStr.hasPrefix(CognitoKeys().redirect_uri) {
                if urlStr.contains("?code=") {
                    // This cancels the navigation
                    parent.viewModel.webViewDismiss.send(true)
                    parent.viewModel.showLoader.send(true)
                    RequestForCallbackURL(request: navigationAction.request)
                    decisionHandler(.cancel)
                    return
                }
            }
            // This allows the navigation
            decisionHandler(.allow)
        }
        
        
        func RequestForCallbackURL(request: URLRequest) {
            // Get the authorization code string after the '?code=' and before '&state='
            let requestURLString = (request.url?.absoluteString)! as String
            print("hit url",requestURLString)
            if requestURLString.hasPrefix(CognitoKeys().redirect_uri) {
                if requestURLString.contains("?code=") {
                    if let range = requestURLString.range(of: "=") {
                        let code = requestURLString[range.upperBound...]
                        print("code>>",code)
                        requestForAccessToken(authCode: String(code))
                    }
                }
            }else {
                parent.viewModel.showLoader.send(false)
            }
        }
        
        func base64EncodeClientCredentials(clientId: String, clientSecret: String) -> String? {
            let combinedCredentials = "\(clientId):\(clientSecret)"
            
            if let data = combinedCredentials.data(using: .utf8) {
                let base64Encoded = data.base64EncodedString()
                return "Basic \(base64Encoded)"
            }
            
            return nil
        }
        
        func requestForAccessToken(authCode: String) {
            
            let tokenEndpoint = "\(CognitoKeys().user_pool_domain)/oauth2/token"
            
            let basicToken = self.base64EncodeClientCredentials(clientId: CognitoKeys().client_id, clientSecret: CognitoKeys().client_secret) ?? ""
            let code = authCode.replacingOccurrences(of: "#", with: "")
            
            let url = URL(string: tokenEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(basicToken, forHTTPHeaderField: "Authorization")
            
            let body = "grant_type=authorization_code&client_id=\(CognitoKeys().client_id)&code=\(code)&redirect_uri=\(CognitoKeys().redirect_uri)"
            request.httpBody = body.data(using: .utf8)
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
            
            let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                
                let statusCode = (response as! HTTPURLResponse).statusCode
                if statusCode == 200 {
                    do {
                        
                        let results = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable: Any]
                        
                        let accessToken = results?["access_token"] as! String
                        print("accessToken is: \(accessToken)")
                        let expiresIn = results?["expires_in"] as! Int
                        print("expires in: \(expiresIn)")
                        let id_token = results?["id_token"] as! String   // user detail
                        print("id_token: \(id_token)")
                        let refresh_token = results?["refresh_token"] as! String
                        print("refresh_token: \(refresh_token)")
                        let token_type = results?["token_type"] as! String
                        print("token_type: \(token_type)")
                        
                        // Get user's id, first name, last name, profile pic url
                        self.fetchUserInfo(accessToken: accessToken)
                    } catch(let error) {
                        print(error)
                        self.parent.viewModel.showLoader.send(false)
                        self.parent.viewModel.webError.send(error.localizedDescription)
                    }
                }
            }
            task.resume()
        }
        
        
        func fetchUserInfo(accessToken: String) {
            let userInfoURL = URL(string: "\(CognitoKeys().user_pool_domain)/oauth2/userInfo")!
            
            var request = URLRequest(url: userInfoURL)
            request.httpMethod = "POST"
            
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let session = URLSession.shared
            let task = session.dataTask(with: request) { (data, response, error) in
                self.parent.viewModel.showLoader.send(false)
                if let error = error {
                    print("Error fetching user info: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let data = data {
                    do {
                        // Parse the JSON response
                        if let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            let name = jsonResult["username"] as? String ?? ""
                            let email = jsonResult["email"] as? String ?? ""
                            let id = jsonResult["sub"] as? String ?? ""
                            print("User Name: \(name)")
                            print("User Email: \(email)")
                            print("User id: \(id)")
                            // Here, send data to server
                            var usr = WebUserData()
                            usr?.userName = name
                            usr?.email = email
                            usr?.userId = id
                            if let usrdata = usr {
                                self.parent.viewModel.webResultPublisher.send(usrdata)
                            }
                            
                        } else {
                            print("Failed to parse JSON response.")
                            self.parent.viewModel.webError.send("Failed to parse JSON response.")
                        }
                    } catch {
                        print("Error while parsing JSON response: \(error)")
                        self.parent.viewModel.webError.send(error.localizedDescription)
                    }
                } else {
                    print("Invalid HTTP response or data.")
                    self.parent.viewModel.webError.send("Invalid HTTP response or data.")
                }
            }
            task.resume()
        }
        
        
    }
    
}

// MARK: - Extensions
extension App_WebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Make sure that your passed delegate is called
        if message.name == "iOSNative" {
            if let body = message.body as? [String: Any?] {
                print(body)
            } else if let body = message.body as? String {
                print(body)
            }
        }
    }
}



class WebViewModel: ObservableObject {
    var webViewNavigationPublisher = PassthroughSubject<WebViewNavigation, Never>()
    var webError = PassthroughSubject<String, Never>()
    var showLoader = PassthroughSubject<Bool, Never>()
    var valuePublisher = PassthroughSubject<String, Never>()
    var webResultPublisher = PassthroughSubject<WebUserData, Never>()
    var webViewDismiss = PassthroughSubject<Bool, Never>()
    var webViewTitle = PassthroughSubject<String, Never>()
}

// For identifiying WebView's forward and backward navigation
enum WebViewNavigation {
    case backward, forward, reload
}


struct WebUserData {
    var userId: String = ""
    var userName: String = ""
    var email: String = ""
    
    init?(){}
}
