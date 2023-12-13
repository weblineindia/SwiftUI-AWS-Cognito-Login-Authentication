//
//  ContentView.swift
//  AWSCognitoAuthentication
//
//  Created by wli on 12/12/23.
//

import SwiftUI

enum LoginType : String {
    case Google = "Google"
    case SignInWithApple = "SignInWithApple"
    case LoginWithAmazon = "LoginWithAmazon"
    case Facebook = "Facebook"
    case UserSignUp = "UserSignUp"
    case UserSignIn = "UserSignIn"
    case None = "None"
}

struct ContentView: View {
    
    @ObservedObject var viewModel = WebViewModel()
    @State var isLoader = false
    @State var isSheetOpen = false
    @State var loginType: String = ""
    @State var webData = WebUserData()
    @State var list: [ListData] = [ListData(id: "1",name: "Login with Google") , ListData(id: "2",name: "Login with Apple"), ListData(id: "3",name: "Login"), ListData(id: "4",name: "Signup")]
    
    var body: some View {
        // webViewNavigationBarHelper
        NavigationView {
            ZStack {
                VStack{
                    ScrollView {
                        Spacer()
                        ForEach(list) { item in
                            Button(item.name) {
                                if item.id == "1" {
                                    loginType = LoginType.Google.rawValue
                                }else if item.id == "2" {
                                    loginType = LoginType.SignInWithApple.rawValue
                                }else if item.id == "3" {
                                    loginType = LoginType.UserSignIn.rawValue
                                }else if item.id == "4" {
                                    loginType = LoginType.UserSignUp.rawValue
                                }
                                
                            }.buttonStyle(.bordered).padding(.top, 20)
                        }
                        
                        VStack(alignment: .leading, spacing:15) {
                            Text(self.webData?.userName.isEmpty != true ? "User: \(self.webData?.userName ?? "")" : "").font(.body)
                            Text(self.webData?.email.isEmpty != true ? "Email: \(self.webData?.email ?? "")" : "").font(.body)
                        }.padding(.top, 30)
                        
                    }
                }
                
                VStack {
                    if isLoader {
                        AppLoaderView()
                    }
                }
                .navigationTitle("Cognito Authentication")
                
                .onReceive(self.viewModel.showLoader.receive(on: RunLoop.main)) { isShow in
                    self.isLoader = isShow
                }
                .onReceive(self.viewModel.webViewDismiss.receive(on: RunLoop.main)) { isDismis in
                    isSheetOpen = !isDismis
                }
                
                .onReceive(self.viewModel.webResultPublisher.receive(on: RunLoop.main)) { webdata in
                    webData = webdata
                }
                .onChange(of: self.loginType, perform: { newValue in
                    isSheetOpen = true
                })
                
                .sheet(isPresented: $isSheetOpen, onDismiss: {
                    isSheetOpen = false
                }) {
                    App_WebView(loadingUrl: self.getUrlFor(type: self.loginType), viewModel: viewModel)
                }
            }
        }
        
        
    }
    
    
    func getUrlFor(type: String)->String {
        var webUrl = ""
        if type == LoginType.Google.rawValue {
            let identity_provider = "Google"
            webUrl = "\(CognitoKeys().user_pool_domain)/oauth2/authorize?identity_provider=\(identity_provider)&client_id=\(CognitoKeys().client_id)&response_type=code&scope=\(CognitoKeys().app_scope)&redirect_uri=\(CognitoKeys().redirect_uri)"
        } else if type == LoginType.SignInWithApple.rawValue {
            let identity_provider = "SignInWithApple"
            webUrl = "\(CognitoKeys().user_pool_domain)/oauth2/authorize?identity_provider=\(identity_provider)&client_id=\(CognitoKeys().client_id)&response_type=code&scope=\(CognitoKeys().app_scope)&redirect_uri=\(CognitoKeys().redirect_uri)"
        } else if type == LoginType.UserSignUp.rawValue {
            let identity_provider = ""
            webUrl = "\(CognitoKeys().user_pool_domain)/signup?identity_provider=\(identity_provider)&client_id=\(CognitoKeys().client_id)&response_type=code&redirect_uri=\(CognitoKeys().redirect_uri)"
            
        } else if type == LoginType.UserSignIn.rawValue {
            webUrl = "\(CognitoKeys().user_pool_domain)/login?client_id=\(CognitoKeys().client_id)&response_type=code&scope=\(CognitoKeys().app_scope)&redirect_uri=\(CognitoKeys().redirect_uri)"
        }
        return webUrl
    }
    
    // For WebView's forward and backward navigation
    var webViewNavigationBarHelper: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(action: {
                    self.viewModel.webViewNavigationPublisher.send(.backward)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .regular))
                        .imageScale(.large)
                        .foregroundColor(.gray)
                }
                Group {
                    Spacer()
                    Divider()
                    Spacer()
                }
                Button(action: {
                    self.viewModel.webViewNavigationPublisher.send(.forward)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .regular))
                        .imageScale(.large)
                        .foregroundColor(.gray)
                }
                Group {
                    Spacer()
                    Divider()
                    Spacer()
                }
                Button(action: {
                    self.viewModel.webViewNavigationPublisher.send(.reload)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .regular))
                        .imageScale(.large)
                        .foregroundColor(.gray).padding(.bottom, 4)
                }
                Spacer()
            }.frame(height: 45)
            Divider()
        }
    }
    
}



//struct CognitoLoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        CognitoLoginView()
//    }
//}

struct ListData : Identifiable {
    var id: String = ""
    var name: String = ""
}






