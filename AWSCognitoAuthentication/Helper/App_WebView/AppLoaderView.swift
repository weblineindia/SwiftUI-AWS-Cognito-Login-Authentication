//
//  AppLoaderView.swift
//  app_components
//
//  Created by wli on 04/12/23.
//

import SwiftUI

struct AppLoaderView: View {
    @State var spinCircle = false
    
    var body: some View {
        ZStack {
            Rectangle().frame(width:160, height: 135).background(Color.black).cornerRadius(8).opacity(0.6).shadow(color: .black, radius: 16)
            VStack {
                Circle()
                    .trim(from: 0.3, to: 1)
                    .stroke(Color.white, lineWidth:3)
                    .frame(width:40, height: 40)
                    .padding(.all, 8)
                    .rotationEffect(.degrees(spinCircle ? 0 : -360), anchor: .center)
                    .animation(Animation.linear(duration: 0.6).repeatForever(autoreverses: false),value:  self.spinCircle)
                
                    .onAppear {
                        self.spinCircle = true
                    }
                Text("Please wait...").foregroundColor(.white)
            }
        }.ignoresSafeArea()
    }
}

struct Loader_Previews: PreviewProvider {
    static var previews: some View {
        AppLoaderView()
    }
}
